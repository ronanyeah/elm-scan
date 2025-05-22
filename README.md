# elm-scan

Analyses an Elm application and exports all definitions and associated type signatures to JSON.

```bash
# bash
elm-scan () {
  local abs_path=$(realpath .)
  local elm_file="$abs_path/elm.json"
  if [ -f "$elm_file" ]; then
    __ELM_JSON_FILE="$elm_file" npm --silent --prefix ./path/to/elm-scan run scan | jq .extracts.Extraction
  else
    echo "no elm.json present"
  fi
}
```

```bash
# Inside an Elm application folder containing `elm.json`
$ elm-scan

# Save output
$ elm-scan > project_definitions.json

# Interact with the json output
$ elm-scan | jless
```