# SPEC: Remember last selected overlay tab

## Scope
Persist the last selected Launchpad overlay tab so closing and reopening the GUI restores the same tab.

## Acceptance criteria
1. Closing the overlay does not force reset to tab 0.
2. Reopening overlay restores last selected tab.
3. Selected tab index is persisted in app preferences.
4. Automated tests verify tab retention behavior.
