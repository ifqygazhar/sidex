import { existsSync, readFileSync, writeFileSync } from 'node:fs';

const version = process.argv[2] || process.env.RELEASE_VERSION;
const semverPattern = /^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;

if (!version || !semverPattern.test(version)) {
  throw new Error(`Release version must be SemVer, got: ${version || '<empty>'}`);
}

function updateJson(file, update) {
  const json = JSON.parse(readFileSync(file, 'utf8'));
  update(json);
  const content = JSON.stringify(json, null, 2).replace(
    /[\u007f-\uffff]/g,
    (char) => `\\u${char.charCodeAt(0).toString(16).padStart(4, '0')}`,
  );
  writeFileSync(file, `${content}\n`);
}

for (const file of [
  'package.json',
  'src-tauri/tauri.conf.json',
  'src-tauri/tauri.sidex-ui.conf.json',
]) {
  updateJson(file, (json) => {
    json.version = version;
  });
}

if (existsSync('package-lock.json')) {
  updateJson('package-lock.json', (json) => {
    json.version = version;
    if (json.packages?.['']) {
      json.packages[''].version = version;
    }
  });
}

const cargoPath = 'src-tauri/Cargo.toml';
const cargoToml = readFileSync(cargoPath, 'utf8');
let foundCargoPackageVersion = false;
const updatedCargoToml = cargoToml.replace(
  /(^\[package\][\s\S]*?^version\s*=\s*)"[^\"]+"/m,
  (_match, prefix) => {
    foundCargoPackageVersion = true;
    return `${prefix}"${version}"`;
  },
);

if (!foundCargoPackageVersion) {
  throw new Error(`Could not update [package] version in ${cargoPath}`);
}

writeFileSync(cargoPath, updatedCargoToml);
console.log(`Applied release version ${version}`);
