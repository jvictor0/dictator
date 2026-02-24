# SPEC: remove-voice-model-mode-trigger

## Problem statement
Voice command model-mode switching is no longer desired from the Launchpad UI.

## Scope
- Remove the Launchpad button for voice-driven model configuration changes.
- Remove app-side action handling and recording flow code tied to that button.
- Keep standard dictation and existing runtime config tab behavior intact.

## Acceptance criteria
1. No `change_agent_model_mode` action in launchpad layout.
2. Launchpad action parser/factory no longer supports that action.
3. App no longer contains handler methods/recording branch for voice model mode.
4. Full test suite passes.
