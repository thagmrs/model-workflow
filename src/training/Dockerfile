FROM public.ecr.aws/lambda/python:3.10

# Instalar dependências
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código
COPY train.py ${LAMBDA_TASK_ROOT}

# Definir handler da Lambda
CMD ["train.handler"]
