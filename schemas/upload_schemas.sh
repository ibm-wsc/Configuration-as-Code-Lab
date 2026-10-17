#!/usr/bin/env bash
# upload_schemas.sh
# Uploads all files in a schema directory to a Pulp File repository using the pulp CLI.
#
# Usage:
#   ./upload_schemas.sh <schema-directory> <relative-path-prefix>
#
# Example:
#   ./upload_schemas.sh ./schemas v1

set -euo pipefail

SCHEMA_DIR="${1:?Usage: $0 <schema-directory> <relative-path-prefix>}"
RELATIVE_PREFIX="${2:?Usage: $0 <schema-directory> <relative-path-prefix>}"
REPOSITORY="zos-schemas"

if [[ ! -d "$SCHEMA_DIR" ]]; then
  echo "ERROR: '$SCHEMA_DIR' is not a directory." >&2
  exit 1
fi

if ! command -v pulp &>/dev/null; then
  echo "ERROR: 'pulp' CLI not found in PATH." >&2
  exit 1
fi

count=0

for filepath in "$SCHEMA_DIR"/*; do
  [[ -f "$filepath" ]] || continue
  filename=$(basename "$filepath")

  echo "Uploading: ${filename}"
  pulp file content upload \
    --file "$filepath" \
    --relative-path "${RELATIVE_PREFIX}/${filename}" \
    --repository "$REPOSITORY"

  (( count++ )) || true
done

if [[ $count -eq 0 ]]; then
  echo "No files found in '${SCHEMA_DIR}'."
else
  echo "Done. Uploaded ${count} file(s) to repository '${REPOSITORY}'."
fi
