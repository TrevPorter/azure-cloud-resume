from azure.identity import DefaultAzureCredential
from azure.cosmos import CosmosClient
import os
import json
import azure.functions as func

app = func.FunctionApp()

@app.function_name(name="GetVisitorCount")
@app.route(
    route="GetVisitorCount",
    methods=["GET"],
    auth_level=func.AuthLevel.ANONYMOUS
)
def get_visitor_count(req: func.HttpRequest) -> func.HttpResponse:
    endpoint = os.environ["COSMOS_ENDPOINT"]

    credential = DefaultAzureCredential()
    client = CosmosClient(endpoint, credential=credential)

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
