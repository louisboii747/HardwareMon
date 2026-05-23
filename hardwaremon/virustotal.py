import requests
from database import get_setting

def check_hash(file_hash):
    VT_API_KEY = get_setting("vt_api_key")
    if not VT_API_KEY:
        return {
            "success": False,
            "message": "VirusTotal API key not set."
        }

    url = f"https://www.virustotal.com/api/v3/files/{file_hash}"

    headers = {
        "x-apikey": VT_API_KEY
    }

    try:
        response = requests.get(
            url,
            headers=headers,
            timeout=10
        )

    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }

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