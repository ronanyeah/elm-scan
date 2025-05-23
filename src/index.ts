import { execSync } from "child_process";
import { existsSync } from "fs";
import { resolve } from "path";
import { colorize } from "json-colorizer";

const cwd = process.cwd();

(async () => {
  const elmJson = resolve(cwd, "elm.json");
  if (!existsSync(elmJson)) {
    return console.error("no elm.json present");
  }
  const projectRoot = resolve(__dirname, "..");
  const content = execSync(
    `__ELM_JSON_FILE="${elmJson}" npm run scan --silent`,
    { encoding: "utf8", cwd: projectRoot }
  );
  const json = JSON.parse(content);
  const data = json.extracts.Extraction;
  console.log(colorize(data));
})().catch(console.error);
