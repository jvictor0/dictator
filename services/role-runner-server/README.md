# Role Runner Server

Simple Swift REST server for single-role execution.

## Endpoint

- `POST /run-role`

Request body:

```json
{
  "work_item_id": "my-work-item",
  "slice_id": "slice-a",
  "role": "implementer"
}
```

## Local run

```bash
cd services/role-runner-server
swift run RoleRunnerServer
```

Environment variables:

- `PORT` (default: `8787`)
- `REPO_ROOT` (default: current directory)
- `RUN_ROLE_SCRIPT` (default: `<REPO_ROOT>/scripts/run-role.sh`)
