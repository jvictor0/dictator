from pydantic import BaseModel, Field


class Segment(BaseModel):
    start_ms: int
    end_ms: int
    text: str


class TranscribeRequest(BaseModel):
    audio_b64: str
    sample_rate: int
    locale: str
    session_id: str


class TranscribeResponse(BaseModel):
    raw_transcript: str
    segments: list[Segment]
    confidence: float = Field(ge=0.0, le=1.0)
    duration_ms: int


class RefineRequest(BaseModel):
    raw_transcript: str
    optional_context: dict = Field(default_factory=dict)
    style_prefs: dict = Field(default_factory=dict)


class RefineResponse(BaseModel):
    revised_text: str
    edit_summary: str
    uncertainty_flags: list[str] = Field(default_factory=list)


class DictateRequest(BaseModel):
    audio_b64: str
    sample_rate: int
    locale: str
    session_id: str
    optional_context: dict = Field(default_factory=dict)
    style_prefs: dict = Field(default_factory=dict)


class DictateResponse(BaseModel):
    raw_transcript: str
    revised_text: str
    edit_summary: str
    uncertainty_flags: list[str] = Field(default_factory=list)
