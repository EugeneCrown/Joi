from fastapi import FastAPI, Response

app = FastAPI()


@app.head("/")
def head_root():
    """Возвращает только заголовки для HEAD‑запросов."""
    return Response(status_code=200)


@app.get("/")
def root():
    return {"message": "Joi server works"}
