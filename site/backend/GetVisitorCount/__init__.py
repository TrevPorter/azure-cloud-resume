import os
import json
import logging

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.cosmos import CosmosClient, exceptions


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("GetVisitorCount function triggered")

    # Read Cosmos endpoint from App Settings
    endpoint = os.environ.get("COSMOS_ENDPOINT")
    if not endpoint:
        logging.error("COSMOS_ENDPOINT is not set")
        return func.HttpResponse(
            "Server misconfiguration",
            status_code=500
        )

    try:
        # Managed Identity auth
        credential = DefaultAzureCredential()
        client = CosmosClient(endpoint, credential=credential)

        database = client.get_database_client("resume")
        container = database.get_container_client("visits")

        # Try to read the counter
        try:
            item = container.read_item(
                item="visitors",
                partition_key="visitors"
            )
        except exceptions.CosmosResourceNotFoundError:
            # First visit
            item = {
                "id": "visitors",
                "count": 0
            }
            container.create_item(item)

        # Increment counter
        item["count"] += 1
        container.replace_item(item=item, body=item)

        return func.HttpResponse(
            json.dumps({"count": item["count"]}),
            mimetype="application/json",
            status_code=200
        )

    except Exception as e:
        logging.exception("Failed to process visitor count")
        return func.HttpResponse(
            "Internal Server Error",
            status_code=500
        )
