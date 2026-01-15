import os
import json
import hashlib
import logging
from datetime import datetime

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.cosmos import CosmosClient, exceptions


def get_client_ip(req: func.HttpRequest) -> str:
    """
    Extract client IP from Front Door / Azure headers.
    """
    xff = req.headers.get("X-Forwarded-For")
    if xff:
        return xff.split(",")[0].strip()

    return req.headers.get("X-Real-IP", "unknown")


def hash_ip(ip: str) -> str:
    return hashlib.sha256(ip.encode()).hexdigest()


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("GetUniqueVisitorCount triggered")

    endpoint = os.environ.get("COSMOS_ENDPOINT")
    if not endpoint:
        return func.HttpResponse("COSMOS_ENDPOINT not set", status_code=500)

    credential = DefaultAzureCredential()
    client = CosmosClient(endpoint, credential=credential)

    database = client.get_database_client("resume")
    container = database.get_container_client("uniqueVisitors")

    today = datetime.utcnow().strftime("%Y-%m-%d")
    client_ip = get_client_ip(req)
    visitor_id = hash_ip(client_ip)

    try:
        # Check if this visitor already exists today
        container.read_item(
            item=visitor_id,
            partition_key=today
        )

        # Already counted
        return func.HttpResponse(
            json.dumps({"unique": False}),
            mimetype="application/json",
            status_code=200
        )

    except exceptions.CosmosResourceNotFoundError:
        # First visit today
        container.create_item({
            "id": visitor_id,
            "date": today
        })

        return func.HttpResponse(
            json.dumps({"unique": True}),
            mimetype="application/json",
            status_code=200
        )
