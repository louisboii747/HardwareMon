# HardwareMon Benchmark Cloud API Contract

Status: design contract only. HardwareMon does not connect to or operate a
benchmark cloud service yet.

The desktop application uses a `BenchmarkComparisonProvider` abstraction. Its
local provider calculates comparisons from the user's SQLite history. The
placeholder remote provider performs no network requests, and the coordinator
always falls back to local comparison when a remote provider is disabled,
offline, times out, or returns an error.

## Privacy model

Submission must always follow an explicit per-result consent action. A future
service should accept anonymous results without user accounts, cookies, device
identifiers, or advertising identifiers. The client payload contains only:

- HardwareMon benchmark and payload schema versions
- CPU model and physical/logical core counts
- GPU model when available
- RAM capacity and speed when available
- Storage class such as NVMe, SATA, SSD, or HDD
- Operating system
- Overall, CPU, memory, and disk scores

The client must never submit host/device names, usernames, serial numbers, IP or
MAC addresses, installed software, personal file metadata, or local database
IDs. The current Dart payload builder intentionally has no fields for this data.

## Common rules

- Base path: `/benchmark`
- JSON request and response bodies
- Score comparisons must only mix identical `benchmark_version` values.
- Hardware model strings should be normalised server-side while retaining the
  submitted value for transparent matching diagnostics.
- No endpoint requires or creates an account.
- Rate limiting can use short-lived transport controls, but IP addresses should
  not be persisted with benchmark records.

## `GET /benchmark/leaderboard`

Query parameters:

```text
benchmark_version=1.0
filter=identical_cpu|identical_cpu_gpu|cpu_family|platform|all
cpu_model=AMD%20Ryzen%207%207800X3D
gpu_model=NVIDIA%20GeForce%20RTX%204070
operating_system=Windows
limit=50
```

Response:

```json
{
  "benchmark_version": "1.0",
  "filter": "identical_cpu_gpu",
  "sample_size": 284,
  "entries": [
    {
      "rank": 1,
      "overall_score": 1824,
      "cpu_score": 1762,
      "memory_score": 1901,
      "disk_score": 1934
    }
  ]
}
```

## `GET /benchmark/compare`

Accepts the same filter and hardware query fields plus the user's component
scores. A production service may choose `POST` if query length or logging
privacy makes a request body preferable.

Response:

```json
{
  "benchmark_version": "1.0",
  "filter": "identical_cpu",
  "sample_size": 431,
  "percentile": 84.2,
  "average_score": 1370.4,
  "average_identical_cpu": 1370.4,
  "average_identical_cpu_gpu": 1412.8,
  "median_score": 1361.0,
  "lowest_score": 821,
  "top_10_percent_score": 1588,
  "highest_score": 1764,
  "component_averages": {
    "cpu": 1401.2,
    "memory": 1298.7,
    "disk": 1359.8
  }
}
```

## `POST /benchmark/upload`

Request (matches `BenchmarkResult.toAnonymousSubmissionJson()`):

```json
{
  "schema_version": 1,
  "benchmark_version": "1.0",
  "hardware": {
    "cpu_model": "AMD Ryzen 7 7800X3D",
    "cpu_cores": 8,
    "cpu_threads": 16,
    "gpu_model": "NVIDIA GeForce RTX 4070",
    "ram_total_bytes": 34359738368,
    "ram_speed_mhz": 6000,
    "storage_type": "NVMe",
    "operating_system": "Windows"
  },
  "scores": {
    "overall": 1538,
    "cpu": 1492,
    "memory": 1511,
    "disk": 1701
  }
}
```

Response:

```json
{
  "accepted": true,
  "anonymous_result_id": "public-random-id",
  "comparison": {
    "sample_size": 431,
    "percentile": 84.2
  }
}
```

The service should generate a random public ID and must not accept a local
database ID or device identifier from the client.

## `GET /benchmark/statistics`

Returns aggregate distributions for charts without exposing individual
submissions:

```json
{
  "benchmark_version": "1.0",
  "filter": "platform",
  "sample_size": 12540,
  "average_score": 1128.3,
  "median_score": 1097.0,
  "lowest_score": 212,
  "top_10_percent_score": 1610,
  "highest_score": 2144
}
```

## Failure behavior

Remote providers should use short timeouts and treat authentication prompts,
invalid payloads, rate limits, server errors, and connectivity failures as
non-fatal. The comparison coordinator must return local results instead. A
failed upload remains local and should be retried only after another explicit
user action.
