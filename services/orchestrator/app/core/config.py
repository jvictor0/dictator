from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    host: str = "127.0.0.1"
    port: int = 8000

    stt_provider: str = "whisper_local"
    whisper_model: str = "tiny"
    whisper_language: str = "en"

    llm_provider: str = "openai"
    openai_api_key: str = ""
    openai_model: str = "gpt-4.1-mini"

    dictation_timeout_seconds: int = 120

    model_config = SettingsConfigDict(env_file=".env", case_sensitive=False)


settings = Settings()
