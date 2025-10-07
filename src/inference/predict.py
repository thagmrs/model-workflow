import os
import json
import boto3
import pandas as pd
import joblib
import numpy as np
import warnings
from fastapi import FastAPI, HTTPException, Header, Depends
from pydantic import BaseModel

warnings.filterwarnings("ignore", message="joblib will operate in serial mode")

# -----------------------------------------------------
# Configurações
# -----------------------------------------------------
s3 = boto3.client("s3")

MODEL_BUCKET = os.environ["ARTIFACTS_BUCKET"]
MODEL_KEY = os.environ.get("MODEL_KEY", "models/latest/model.joblib")
LOCAL_MODEL_PATH = "/tmp/model.joblib"
API_KEY = os.environ.get("API_KEY", "thais-secret-123")

app = FastAPI(
    title="Property Price Predictor API",
    description="""
API de inferência de preços imobiliários treinada com GradientBoostingRegressor.

Esta API permite:
- Prever o preço de um imóvel com base em suas características.
- Checar o status do container via rota `/health`.
- Acessar documentação interativa em `/docs` (Swagger UI).
""",
    version="2.0.0"
)

model = None
last_modified = None

# -----------------------------------------------------
# Modelo de entrada (Pydantic)
# -----------------------------------------------------
class Features(BaseModel):
    type: str
    sector: str
    net_usable_area: float
    net_area: float
    n_rooms: float
    n_bathroom: float
    latitude: float
    longitude: float

# -----------------------------------------------------
# Função de carregamento do modelo
# -----------------------------------------------------
def load_model():
    """Baixa e mantém em cache o modelo mais recente do S3."""
    global model, last_modified
    try:
        head = s3.head_object(Bucket=MODEL_BUCKET, Key=MODEL_KEY)
        modified = head["LastModified"]

        if model is None or last_modified != modified:
            print(f"🔁 Baixando modelo atualizado: {MODEL_KEY}")
            s3.download_file(MODEL_BUCKET, MODEL_KEY, LOCAL_MODEL_PATH)
            model = joblib.load(LOCAL_MODEL_PATH)
            last_modified = modified
            print(f"✅ Modelo carregado ({modified})")
        return model
    except Exception as e:
        print(f"❌ Erro ao carregar modelo: {e}")
        raise HTTPException(status_code=500, detail=f"Erro ao carregar modelo: {e}")

# -----------------------------------------------------
# Rotas da API
# -----------------------------------------------------

@app.get("/health", summary="Verifica o status da API")
def health_check():
    """Retorna o status da API e se o modelo está carregado."""
    try:
        _ = load_model()
        return {
            "status": "healthy",
            "service": "predictor",
            "model_loaded": model is not None,
            "model_key": MODEL_KEY,
        }
    except Exception as e:
        return {"status": "unhealthy", "error": str(e)}


@app.post(
    "/predict",
    summary="Realiza a predição de preço",
)
def predict(features: Features):
    """Recebe as features e retorna o valor previsto."""
    try:
        df = pd.DataFrame([features.dict()])  # input → DataFrame
        m = load_model()                      # carrega modelo atualizado
        preds = m.predict(df)                 # realiza inferência

        result = {
            "status": "ok",
            "prediction": float(preds[0]),
            "model_version": last_modified.isoformat(),
        }

        print("✅ Resultado:", result)
        return result
    except Exception as e:
        print(f"❌ Erro na predição: {e}")
        raise HTTPException(status_code=500, detail=f"Erro na predição: {e}")

# -----------------------------------------------------
# Execução local (para debug)
# -----------------------------------------------------
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
