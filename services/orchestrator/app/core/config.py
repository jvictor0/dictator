from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Literal


class Settings(BaseSettings):
    host: str = "127.0.0.1"
    port: int = 8000

    stt_provider: str = "whisper_local"
    whisper_model: str = "tiny"
    whisper_language: str = "en"

    llm_provider: str = "openai"
    openai_api_key: str = ""
    openai_model: str = "gpt-4.1-mini"
    refinement_fallback_mode: Literal["use_raw", "fail_closed"] = "use_raw"

    dictation_timeout_seconds: int = 120

    model_config = SettingsConfigDict(env_file=".env", case_sensitive=False)


settings = Settings()
