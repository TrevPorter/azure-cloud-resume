import os
import json
import logging

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.cosmos import CosmosClient


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("GetVisitorCount triggered")

    endpoint = os.environ["COSMOS_ENDPOINT"]

    credential = DefaultAzureCredential()
    client = CosmosClient(endpoint, credential=credential)

    database = client.get_database_client("resume")
    container = database.get_container_client("visits")

    try:
        item = container.read_item(
            item="visitors",
            partition_key="visitors"
        )
    except Exception:
        item = {
            "id": "visitors",
            "count": 0
        }
        container.create_item(item)

    item["count"] += 1
    container.replace_item(item=item, body=item)

    return func.HttpResponse(
        json.dumps({"count": item["count"]}),
        mimetype="application/json",
        status_code=200
    )
