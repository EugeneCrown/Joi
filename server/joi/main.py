from fastapi import FastAPI, Response

app = FastAPI()


@app.head("/")
def head_root():
    """Отдаёт простой ответ на HEAD запросы для проверки работоспособности сервера."""
    return Response(content="Joi server works", media_type="text/plain")


@app.get("/")
def root():
    return {"message": "Joi server works"}
