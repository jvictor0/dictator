from abc import ABC, abstractmethod

from app.models.contracts import RefineRequest, RefineResponse


class LLMProvider(ABC):
    @abstractmethod
    def refine(self, req: RefineRequest) -> RefineResponse:
        raise NotImplementedError
