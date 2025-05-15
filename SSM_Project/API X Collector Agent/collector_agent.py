import psutil
import requests
import database
from datetime import datetime
import math

disk = psutil.disk_usage('/')
cpu_percentage = psutil.cpu_percent()
mem = psutil.virtual_memory()

mem_used_GB = round((mem.used / math.pow(10,9)), 4)
mem_total_GB = round((mem.total / math.pow(10,9)), 4)
mem_free_GB = round((mem_total_GB - mem_used_GB), 4)

disk_used_GB = round((disk.used / math.pow(10,9)), 4)
disk_total_GB = round((disk.total / math.pow(10,9)), 4)
disk_free_GB = round((disk_total_GB - disk_used_GB), 4)

rec_time = datetime.now().isoformat(timespec='minutes')

performance_stats = {
    "mem_used_GB": mem_used_GB,
    "mem_total_GB": mem_total_GB,
    "mem_free_GB": mem_free_GB,
    "cpu_percentage": cpu_percentage,
    "disk_total_GB": disk_total_GB,
    "disk_used_GB": disk_used_GB,
    "disk_free_GB": disk_free_GB,
    "rec_time": rec_time

}

try:
    print("Sending data to API...")
    response = requests.post("http://127.0.0.1:8000/track", json=performance_stats)
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.text}")
except requests.exceptions.RequestException as e:
    print(f"Error: {e}")
