from fastapi import FastAPI, Response

app = FastAPI()


@app.head("/")
def head_root():
    """Возвращает только заголовки для HEAD‑запросов, включая статус работы сервера."""
    return Response(status_code=200, headers={"X-Joi-Status": "Joi works"})


@app.get("/")
def root():
    return {"message": "Joi server works"}
