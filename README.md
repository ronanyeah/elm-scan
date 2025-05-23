# elm-scan

Analyses an Elm application and exports all definitions and associated type signatures to JSON.

### Setup
- `git clone git@github.com:ronanyeah/elm-scan.git`
- `cd elm-scan`
- `npm install --production`
- `npm install --global .`

### Usage
```bash
# Inside an Elm application folder containing `elm.json`
$ elm-scan

# Save output
$ elm-scan > project_definitions.json

# Interact with the json output
$ elm-scan | jless
```