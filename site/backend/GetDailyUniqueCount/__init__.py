import os
import json
import hashlib
import logging
from datetime import datetime

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.cosmos import CosmosClient, exceptions


def get_client_ip(req: func.HttpRequest) -> str:
    xff = req.headers.get("X-Forwarded-For")
    if xff:
        return xff.split(",")[0].strip()
    return req.headers.get("X-Real-IP", "unknown")


def hash_ip(ip: str) -> str:
    return hashlib.sha256(ip.encode()).hexdigest()


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("GetDailyUniqueCount triggered")

    endpoint = os.environ.get("COSMOS_ENDPOINT")
    if not endpoint:
        return func.HttpResponse("COSMOS_ENDPOINT not set", status_code=500)

    credential = DefaultAzureCredential()
    client = CosmosClient(endpoint, credential=credential)

    db = client.get_database_client("resume")
    visitors = db.get_container_client("uniqueVisitors")
    counts = db.get_container_client("dailyCounts")

    today = datetime.utcnow().strftime("%Y-%m-%d")
    visitor_id = hash_ip(get_client_ip(req))

    # 1️⃣ Check if visitor already counted today
    try:
        visitors.read_item(visitor_id, partition_key=today)
        already_counted = True
    except exceptions.CosmosResourceNotFoundError:
        already_counted = False

    # 2️⃣ If new visitor, record + increment
    if not already_counted:
        visitors.create_item({
            "id": visitor_id,
            "date": today
        })

        try:
            counter = counts.read_item(today, partition_key=today)
            counter["count"] += 1
            counts.replace_item(counter, counter)
        except exceptions.CosmosResourceNotFoundError:
            counts.create_item({
                "id": today,
                "date": today,
                "count": 1
            })

    # 3️⃣ Read and return current count
    counter = counts.read_item(today, partition_key=today)

    return func.HttpResponse(
        json.dumps({"date": today, "count": counter["count"]}),
        mimetype="application/json",
        status_code=200
    )
