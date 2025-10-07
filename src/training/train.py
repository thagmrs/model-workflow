import os
import json
import boto3
import pandas as pd
import numpy as np
import joblib

from urllib.parse import unquote_plus
from sklearn.metrics import (
    mean_squared_error,
    mean_absolute_percentage_error,
    mean_absolute_error
)
from category_encoders import TargetEncoder
from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.model_selection import train_test_split

s3 = boto3.client("s3")

def handler(event, context):
    print("Evento original recebido:")
    print(json.dumps(event))

    # ------------------------------------------------------------------
    # 1️⃣ Caso o evento venha via SNS, extrai o JSON interno
    # ------------------------------------------------------------------
    if "Records" in event and "Sns" in event["Records"][0]:
        sns_message = event["Records"][0]["Sns"]["Message"]
        print("Evento via SNS detectado. Mensagem SNS decodificada:")
        event = json.loads(sns_message)
        print(json.dumps(event))

    # ------------------------------------------------------------------
    # 2️⃣ Extrair bucket e key do evento S3
    # ------------------------------------------------------------------
    try:
        record = event["Records"][0]
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]
        key = unquote_plus(key)  # corrige codificação tipo %2F
    except Exception as e:
        print("❌ Erro ao extrair bucket/key do evento:", str(e))
        return {"error": "Formato de evento inválido", "detail": str(e)}

    print(f"📦 Bucket: {bucket}")
    print(f"📄 Arquivo: {key}")

    # ------------------------------------------------------------------
    # 3️⃣ Ignorar arquivos que não são CSV
    # ------------------------------------------------------------------
    if not key.endswith(".csv"):
        print("Ignorado: o arquivo não é um CSV.")
        return {"message": "Ignorado (não é CSV)"}

    # ------------------------------------------------------------------
    # 4️⃣ Baixar dataset do S3
    # ------------------------------------------------------------------
    local_file = "/tmp/data.csv"
    try:
        print(f"⬇️ Baixando arquivo s3://{bucket}/{key} ...")
        s3.download_file(bucket, key, local_file)
        print("Download concluído.")
    except Exception as e:
        print("❌ Erro ao baixar arquivo do S3:", str(e))
        return {"error": "Falha no download do arquivo", "detail": str(e)}

    # ------------------------------------------------------------------
    # 5️⃣ Carregar dataset e preparar dados
    # ------------------------------------------------------------------
    df = pd.read_csv(local_file)
    print(f"✅ Dataset carregado com {df.shape[0]} linhas e {df.shape[1]} colunas")

    target_col = "price"
    categorical_cols = ["type", "sector"]
    train_cols = [col for col in df.columns if col not in ["id", target_col]]

    # ------------------------------------------------------------------
    # 6️⃣ Split train/test
    # ------------------------------------------------------------------
    train_df, test_df = train_test_split(df, test_size=0.2, random_state=42)

    # ------------------------------------------------------------------
    # 7️⃣ Pré-processamento (TargetEncoder nas categorias)
    # ------------------------------------------------------------------
    categorical_transformer = TargetEncoder()

    preprocessor = ColumnTransformer(
        transformers=[
            ('categorical', categorical_transformer, categorical_cols)
        ],
        remainder="passthrough"
    )

    # ------------------------------------------------------------------
    # 8️⃣ Modelo Gradient Boosting
    # ------------------------------------------------------------------
    gbr = GradientBoostingRegressor(
        learning_rate=0.01,
        n_estimators=300,
        max_depth=5,
        loss="absolute_error",
        random_state=42
    )

    pipeline = Pipeline(steps=[
        ('preprocessor', preprocessor),
        ('model', gbr)
    ])

    # ------------------------------------------------------------------
    # 9️⃣ Treinar modelo
    # ------------------------------------------------------------------
    print("🚀 Treinando modelo...")
    pipeline.fit(train_df[train_cols], train_df[target_col])
    print("✅ Treinamento concluído.")

    # ------------------------------------------------------------------
    # 🔟 Avaliar modelo
    # ------------------------------------------------------------------
    preds = pipeline.predict(test_df[train_cols])
    rmse = np.sqrt(mean_squared_error(test_df[target_col], preds))
    mape = mean_absolute_percentage_error(test_df[target_col], preds)
    mae = mean_absolute_error(test_df[target_col], preds)

    print(f"📊 Métricas: RMSE={rmse:.4f}, MAPE={mape:.4f}, MAE={mae:.4f}")

    # ------------------------------------------------------------------
    # 11️⃣ Salvar e enviar o modelo treinado ao bucket de artefatos
    # ------------------------------------------------------------------
    model_path = "/tmp/model.joblib"
    joblib.dump(pipeline, model_path)
    print("💾 Modelo salvo localmente.")

    artifacts_bucket = os.environ["ARTIFACTS_BUCKET"]
    output_key = f"models/{os.path.basename(key).replace('.csv','')}/model.joblib"

    try:
        s3.upload_file(model_path, artifacts_bucket, output_key)
        print(f"✅ Modelo enviado para s3://{artifacts_bucket}/{output_key}")
        # Após s3.upload_file(...)
        latest_key = "models/latest/model.joblib"
        s3.upload_file(model_path, artifacts_bucket, latest_key)
        print(f"🟢 Modelo mais recente atualizado em s3://{artifacts_bucket}/{latest_key}")

    except Exception as e:
        print("❌ Erro ao enviar modelo para S3:", str(e))
        return {"error": "Falha no upload do modelo", "detail": str(e)}

    return {
        "status": "ok",
        "artifact": f"s3://{artifacts_bucket}/{output_key}",
        "metrics": {"rmse": rmse, "mape": mape, "mae": mae}
    }
