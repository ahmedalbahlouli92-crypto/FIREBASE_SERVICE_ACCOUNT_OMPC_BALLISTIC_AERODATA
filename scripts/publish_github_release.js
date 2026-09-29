const fs = require('fs');
const https = require('https');
const path = require('path');
const { execSync } = require('child_process');

function getGitHubToken() {
  if (process.env.GITHUB_TOKEN) return process.env.GITHUB_TOKEN;
  try {
    const remote = execSync('git remote get-url origin').toString().trim();
    const match = remote.match(/:([^@]+)@/);
    if (match) {
      const parts = match[1].split(':');
      return parts[parts.length - 1];
    }
  } catch (e) {}
  return '';
}

const GITHUB_TOKEN = getGitHubToken();
const OWNER = 'ahmedalbahlouli92-crypto';
const REPO = 'FIREBASE_SERVICE_ACCOUNT_OMPC_BALLISTIC_AERODATA';
const TAG_NAME = 'v1.6.1';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.6.1 (EPVAT Multi-Temp Evaluation Fix, Round & Stat Serialization, Remarks Safety)';
const BODY = `## OMPC Ballistic AeroData v1.6.1

Comprehensive update resolving EPVAT multi-temperature differential evaluation zero-result bug, enhancing round and telemetry serialization across all modes, and preserving notes metadata during record editing.

### Bug Fixes & Improvements:
1. **EPVAT Temperature Differential Evaluation Fix**:
   - Fixed variable resolution in formula evaluation: non-baseline temperature variables (such as \`p2_mean_52\` or \`vel_mean_54\`) no longer incorrectly fall back to the +21°C baseline.
   - Previously, if telemetry for +52°C or -54°C was missing or unmapped, the formula subtracted the baseline from itself (e.g. \`Mean P2 @52 - Mean P2 @21\` calculated \`1201.5 - 1201.5 = 0.0 bar\`), yielding false 0.0 results.
   - Now, temperature suffixes are strictly validated. If a temperature metric is absent, evaluation handles it properly without false 0.0 equality.
2. **Stats-Only Multi-Temperature Telemetry Persistence**:
   - In "Stats Only" entry mode (where rounds are not entered individually), EPVAT summary statistics are now serialized into round fields using standard \`STAT:P1=...,Max=...,Min=...,SD=...\` encoding separated by semicolons (\`;\`).
   - Slot alignment across temperatures is strictly preserved even when individual temperatures have empty fields.
3. **Resilient Temperature Extraction**:
   - Replaced comma-splitting with regex-based temperature matching (\`RegExp(r'([+-]?\\d+)')\`), properly parsing multi-temperature configurations whether separated by commas, spaces, or tabs (e.g. \`+21°C  +52°C  -54°C\` from CSV / Supabase).
4. **Remarks & Notes Protection**:
   - In History Log Edit dialog, user remarks are cleanly separated from internal \`Temps:\` metadata via \`ReportGenerator.cleanRemarks\`.
   - On saving record updates, existing \`Temps:\` telemetry is preserved, preventing edits from wiping out multi-temperature statistics.
5. **Cross-Platform Deployments**:
   - **Web Application**: Live on Firebase Hosting at https://ompc-ballistic-aerodata.web.app.
   - **Windows Desktop**: 1-Click Setup Installer (\`OMPC_Ballistic_AeroData_Setup.exe\`), Standalone Executable (\`OMPC_Ballistic_AeroData.exe\`), and Portable ZIP.
   - **Android APK**: Updated release APK (\`OMPC_Ballistic_AeroData_v1.6.1.apk\`).
`;

function request(options, postData) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ statusCode: res.statusCode, headers: res.headers, body: JSON.parse(data) });
        } catch (e) {
          resolve({ statusCode: res.statusCode, headers: res.headers, body: data });
        }
      });
    });
    req.on('error', reject);
    if (postData) {
      req.write(postData);
    }
    req.end();
  });
}

function uploadAsset(uploadUrlTemplate, filePath, fileName) {
  return new Promise((resolve, reject) => {
    const uploadUrl = new URL(uploadUrlTemplate.replace('{?name,label}', `?name=${encodeURIComponent(fileName)}`));
    const stats = fs.statSync(filePath);
    const readStream = fs.createReadStream(filePath);

    console.log(`Uploading ${fileName} (${(stats.size / (1024 * 1024)).toFixed(2)} MB)...`);

    const req = https.request({
      hostname: uploadUrl.hostname,
      path: uploadUrl.pathname + uploadUrl.search,
      method: 'POST',
      headers: {
        'User-Agent': 'NodeJS-Release-Uploader',
        'Authorization': `token ${GITHUB_TOKEN}`,
        'Content-Type': 'application/octet-stream',
        'Content-Length': stats.size
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        console.log(`Uploaded ${fileName}: HTTP ${res.statusCode}`);
        resolve({ statusCode: res.statusCode, body: data });
      });
    });

    req.on('error', (err) => {
      console.error(`Error uploading ${fileName}:`, err);
      reject(err);
    });

    readStream.pipe(req);
  });
}

async function main() {
  console.log('Getting or creating GitHub Release on repository...');
  const releasePayload = JSON.stringify({
    tag_name: TAG_NAME,
    target_commitish: 'main',
    name: RELEASE_NAME,
    body: BODY,
    draft: false,
    prerelease: false
  });

  let release;
  const createRes = await request({
    hostname: 'api.github.com',
    path: `/repos/${OWNER}/${REPO}/releases`,
    method: 'POST',
    headers: {
      'User-Agent': 'NodeJS-Release-Uploader',
      'Authorization': `token ${GITHUB_TOKEN}`,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(releasePayload)
    }
  }, releasePayload);

  if (createRes.statusCode === 201) {
    release = createRes.body;
    console.log(`Release created: ${release.html_url}`);
  } else {
    console.log(`Release already exists (HTTP ${createRes.statusCode}), fetching existing release...`);
    const getRes = await request({
      hostname: 'api.github.com',
      path: `/repos/${OWNER}/${REPO}/releases/tags/${TAG_NAME}`,
      method: 'GET',
      headers: {
        'User-Agent': 'NodeJS-Release-Uploader',
        'Authorization': `token ${GITHUB_TOKEN}`
      }
    });
    release = getRes.body;
    console.log(`Fetched release: ${release.html_url}`);
  }

  const uploadUrl = release.upload_url;
  const existingAssets = release.assets || [];

  const assets = [
    { name: 'OMPC_Ballistic_AeroData_Setup.exe', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_Setup.exe' },
    { name: 'OMPC_Ballistic_AeroData.exe', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData.exe' },
    { name: 'OMPC_Ballistic_AeroData_Portable.zip', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_Portable.zip' },
    { name: 'Force_Unlock_All.bat', path: 'C:\\Users\\user\\Desktop\\Force_Unlock_All.bat' },
    { name: 'OMPC_Ballistic_AeroData_v1.6.1.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.6.1.apk' },
    { name: 'OMPC_Ballistic_AeroData_v1.5.9.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.5.9.apk' },
    { name: 'OMPC_Ballistic_AeroData.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData.apk' },
    { name: 'supabase_tables_setup.sql', path: path.join(__dirname, '..', 'supabase_tables_setup.sql') }
  ];

  for (const asset of assets) {
    if (fs.existsSync(asset.path)) {
      // Check if already exists in release and delete first
      const existing = existingAssets.find(a => a.name === asset.name);
      if (existing) {
        console.log(`Deleting existing ${asset.name} (id: ${existing.id})...`);
        await request({
          hostname: 'api.github.com',
          path: `/repos/${OWNER}/${REPO}/releases/assets/${existing.id}`,
          method: 'DELETE',
          headers: {
            'User-Agent': 'NodeJS-Release-Uploader',
            'Authorization': `token ${GITHUB_TOKEN}`
          }
        });
      }
      await uploadAsset(uploadUrl, asset.path, asset.name);
    } else {
      console.log(`Skipping ${asset.name} (file not ready yet at ${asset.path})`);
    }
  }

  console.log('GitHub Release assets synchronized successfully!');
  console.log(`View at: ${release.html_url}`);
}

main().catch(console.error);
