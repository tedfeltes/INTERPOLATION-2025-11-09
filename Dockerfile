FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY static ./static
RUN mkdir -p data/uploads data/outputs

ENV PYTHONUNBUFFERED=1
EXPOSE 8000

CMD ["python", "-m", "app"]
