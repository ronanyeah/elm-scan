# elm-scan

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
```