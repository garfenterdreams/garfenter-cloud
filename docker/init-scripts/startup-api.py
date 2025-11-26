from flask import Flask, jsonify
import docker, os

app = Flask(__name__)
client = docker.from_env()

PG = os.environ.get("POSTGRES_PASSWORD", "")
MY = os.environ.get("MYSQL_PASSWORD", "")
JWT = os.environ.get("JWT_SECRET", "")

P = {
    "tienda": {"c": "garfenter-tienda", "p": 8000, "i": "ghcr.io/saleor/saleor:3.19",
        "e": {"DATABASE_URL": f"postgresql://garfenter:{PG}@garfenter-postgres:5432/garfenter_tienda", "SECRET_KEY": JWT, "ALLOWED_HOSTS": "*", "DEBUG": "False"}},
    "mercado": {"c": "garfenter-mercado", "p": 8000, "i": "spurtcommerce/spurtcommerce:latest",
        "e": {"TYPEORM_HOST": "garfenter-mysql", "TYPEORM_USERNAME": "garfenter", "TYPEORM_PASSWORD": MY, "TYPEORM_DATABASE": "garfenter_mercado"}},
    "pos": {"c": "garfenter-pos", "p": 80, "i": "opensourcepos/opensourcepos:latest",
        "e": {"DB_HOST": "garfenter-mysql", "DB_NAME": "garfenter_pos", "DB_USER": "garfenter", "DB_PASS": MY}},
    "contable": {"c": "garfenter-contable", "p": 3000, "i": "bigcapital/bigcapital:latest",
        "e": {"DATABASE_URL": f"postgresql://garfenter:{PG}@garfenter-postgres:5432/garfenter_contable", "JWT_SECRET": JWT}},
    "erp": {"c": "garfenter-erp", "p": 8069, "i": "odoo:17",
        "e": {"HOST": "garfenter-postgres", "USER": "garfenter", "PASSWORD": PG}},
    "clientes": {"c": "garfenter-clientes", "p": 3000, "i": "twentycrm/twenty:latest",
        "e": {"PG_DATABASE_URL": f"postgresql://garfenter:{PG}@garfenter-postgres:5432/garfenter_clientes", "ACCESS_TOKEN_SECRET": JWT}},
    "inmuebles": {"c": "garfenter-inmuebles", "p": 3000, "i": "condo-app/condo:latest",
        "e": {"DATABASE_URL": f"postgresql://garfenter:{PG}@garfenter-postgres:5432/garfenter_inmuebles", "JWT_SECRET": JWT}},
    "campo": {"c": "garfenter-campo", "p": 80, "i": "farmos/farmos:3.x",
        "e": {"FARMOS_DB_HOST": "garfenter-postgres", "FARMOS_DB_USER": "garfenter", "FARMOS_DB_PASS": PG, "FARMOS_DB_NAME": "garfenter_campo"}},
    "banco": {"c": "garfenter-banco", "p": 8443, "i": "apache/fineract:latest",
        "e": {"FINERACT_HIKARI_JDBC_URL": f"jdbc:mysql://garfenter-mysql:3306/garfenter_banco", "FINERACT_HIKARI_USERNAME": "garfenter", "FINERACT_HIKARI_PASSWORD": MY}},
    "salud": {"c": "garfenter-salud", "p": 80, "i": "hmis/hmis:latest",
        "e": {"DB_HOST": "garfenter-mysql", "DB_DATABASE": "garfenter_salud", "DB_USERNAME": "garfenter", "DB_PASSWORD": MY}},
    "educacion": {"c": "garfenter-educacion", "p": 3000, "i": "instructure/canvas-lms:stable",
        "e": {"POSTGRES_HOST": "garfenter-postgres", "POSTGRES_USER": "garfenter", "POSTGRES_PASSWORD": PG, "POSTGRES_DB": "garfenter_educacion"}},
}

def running(n):
    try: return client.containers.get(n).status == "running"
    except: return False

def stop(n):
    try:
        c = client.containers.get(n)
        c.stop(timeout=10)
        c.remove()
    except: pass

@app.route("/api/start/<p>", methods=["POST"])
def start(p):
    if p not in P: return jsonify({"error": "Unknown"}), 404
    i = P[p]
    if running(i["c"]): return jsonify({"status": "running"})
    for k, v in P.items():
        if k != p: stop(v["c"])
    try:
        stop(i["c"])
        client.containers.run(i["i"], name=i["c"], network="garfenter-network",
            ports={f"{i['p']}/tcp": i["p"]}, environment=i.get("e", {}), detach=True, mem_limit="512m")
        return jsonify({"status": "starting"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/status/<p>", methods=["GET"])
def status_one(p):
    if p not in P: return jsonify({"error": "Unknown"}), 404
    return jsonify({"running": running(P[p]["c"])})

@app.route("/api/status", methods=["GET"])
def status_all():
    return jsonify({p: running(i["c"]) for p, i in P.items()})

@app.route("/api/stop/<p>", methods=["POST"])
def stop_one(p):
    if p not in P: return jsonify({"error": "Unknown"}), 404
    stop(P[p]["c"])
    return jsonify({"status": "stopped"})

@app.route("/health")
def health():
    return "OK"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
