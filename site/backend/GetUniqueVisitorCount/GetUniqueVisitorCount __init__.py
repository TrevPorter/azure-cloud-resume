import os
import json
import hashlib
from datetime import datetime, timezone
import azure.functions as func
from azure.cosmos import CosmosClient

def main(req: func.HttpRequest) -> func.HttpResponse:
    visitor_ip = get_client_ip(req)
    visitor_hash = hash_visitor(visitor_ip)

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    cosmos = CosmosClient(
        os.environ["COSMOS_ENDPOINT"],
        credential=os.environ["COSMOS_KEY"]
    )

    container = cosmos.get_database_client("resume").get_container_client("uniqueVisitors")

    record_id = f"{visitor_hash}_{today}"

    try:
        container.read_item(record_id, partition_key=today)
        # Visitor already counted today
    except Exception:
        container.create_item({
            "id": record_id,
            "visitorHash": visitor_hash,
            "date": today,
            "createdAt": datetime.utcnow().isoformat()
        })

    count = get_today_unique_count(container, today)

    return func.HttpResponse(
        json.dumps({"uniqueVisitors": count}),
        mimetype="application/json"
    )
def get_client_ip(req):
    return (
        req.headers.get("X-Azure-ClientIP")
        or req.headers.get("X-Forwarded-For", "").split(",")[0]
        or "unknown"
    )

def hash_visitor(ip):
    return hashlib.sha256(ip.encode()).hexdigest()

def get_today_unique_count(container, date):
    query = "SELECT VALUE COUNT(1) FROM c WHERE c.date = @date"
    params = [{"name": "@date", "value": date}]
    return list(container.query_items(
        query=query,
        parameters=params,
        enable_cross_partition_query=True
    ))[0]
