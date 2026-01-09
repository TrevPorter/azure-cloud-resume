import json
import azure.functions as func
import os
from azure.cosmos import CosmosClient

app = func.FunctionApp()

@app.function_name(name="GetVisitorCount")
@app.route(route="GetVisitorCount", methods=["GET"], auth_level=func.AuthLevel.FUNCTION)
def get_visitor_count(req: func.HttpRequest) -> func.HttpResponse:
    endpoint = os.environ["COSMOS_ENDPOINT"]
    key = os.environ["COSMOS_KEY"]

    client = CosmosClient(endpoint, key)
    database = client.get_database_client("resume")
    container = database.get_container_client("container")

    item = container.read_item(
        item="visitors",
        partition_key="visitors"
    )

    item["count"] += 1
    container.replace_item(item=item, body=item)

    return func.HttpResponse(
        json.dumps({"count": item["count"]}),
        mimetype="application/json"
    )
