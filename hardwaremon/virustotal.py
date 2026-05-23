import requests
import os

VT_API_KEY = os.getenv("VT_API_KEY")

if not VT_API_KEY:
    raise RuntimeError("VT_API_KEY environment variable not set")

def check_hash(file_hash):

    url = f"https://www.virustotal.com/api/v3/files/{file_hash}"

    headers = {
        "x-apikey": VT_API_KEY
    }

    response = requests.get(url, headers=headers)

    if response.status_code == 200:

        data = response.json()

        stats = data["data"]["attributes"]["last_analysis_stats"]

        return {
            "success": True,
            "malicious": stats["malicious"],
            "suspicious": stats["suspicious"],
            "undetected": stats["undetected"]
        }

    elif response.status_code == 404:

        return {
            "success": False,
            "message": "File not currently indexed by VirusTotal"
        }

    else:

        return {
            "success": False,
            "error": response.text
        }