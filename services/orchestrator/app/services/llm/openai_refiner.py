from app.models.contracts import RefineRequest, RefineResponse
from app.services.llm.base import LLMProvider


class OpenAIRefiner(LLMProvider):
    """
    Thin placeholder for cloud LLM refinement.
    Replace this method with real API-key based provider calls.
    """

    def refine(self, req: RefineRequest) -> RefineResponse:
        revised = req.raw_transcript.strip().capitalize()
        return RefineResponse(
            revised_text=revised,
            edit_summary="Applied basic punctuation/casing normalization.",
            uncertainty_flags=[],
        )
