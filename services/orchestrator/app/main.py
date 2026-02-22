import logging
from fastapi import FastAPI

from app.api.routes import router


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        force=True,
    )


def create_app() -> FastAPI:
    configure_logging()
    app = FastAPI(title="Dictator Orchestrator", version="0.1.0")
    app.include_router(router)
    return app


app = create_app()
