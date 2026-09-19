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
const TAG_NAME = 'v1.2.0';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.2.0 (Pure White & Sea Blue Theme, Box Plot & Full Lab Overhaul)';
const BODY = `## OMPC Ballistic AeroData v1.2.0

### Key Updates & Laboratory Enhancements:
1. **Pure Modern White & Sea Blue Theme**: Zero dark colors anywhere; pristine white surfaces, sea-blue accents (#0284C7), and crisp crystal-clear typography.
2. **Official OMPC Crest Header**: Restored official OMPC crest in sidebar header, login portal, and reports, while maintaining Flutter origami bird icon for Windows desktop, taskbar, installer, and mobile.
3. **Live Digital Clock & Welcome Greeting**: Added real-time ticking digital clock and personalized welcome greeting badge in top navigation bar.
4. **Lot Acceptance KPI & Reporting**: Dedicated KPI counter for unique lots and tests; Lot Acceptance filter selection now shows all associated tests and exports complete lot test batches in CSV, Word, and Print formats.
5. **Dashboard Box & Whisker Chart**: Added comprehensive Box-Plot analysis (Min, Q1, Median, Q3, Max) across ballistic metrics.
6. **Accuracy Mean Trend Line**: Calculated (Mean X + Mean Y) / 2 to show a clean single average trend line with smooth area gradient.
7. **Strict Numeric Inputs**: All numeric and ballistic measurement fields strictly enforce valid numeric values.
8. **Auto-Generated Waterproof Pressure**: Caliber-aware fixed default pressure (0.14 bar for M82/M200, 0.5 bar for all others).
9. **Dynamic Sample Size Calculation**: Auto-computes tested rounds based on individual results entered.
10. **Inspection Log Reorganization**: Split Sample Size into its own dedicated column separate from Key Results.
11. **Inspection Filters**: Instant filtering by Lot Number and Hopper Number.
12. **Hopper Number Formatting**: Enforced XXX-YYYY format (3-digit user input with fixed hyphen and editable year).
13. **Accuracy Largest Distance Metric**: Added Largest distance (mm) tracking and export.
14. **Cascading Weapon Selection**: Weapon dropdown cascades to Serial Number dropdown with custom 'Other' option, defaulting to Pistol for 9mm.
15. **Residual Stress Room Temp Validation**: Room Temperature (°C) field with auto-jump validation.
16. **Sample Location Management**: Dropdown selection with custom location addition capability.

### Download Binaries:
- **OMPC_Ballistic_AeroData_Setup.exe**: Windows 1-Click Installer
- **OMPC_Ballistic_AeroData.exe**: Standalone Direct Executable
- **OMPC_Ballistic_AeroData_Portable.zip**: Complete Offline Portable Package
- **OMPC_Ballistic_AeroData.apk**: Android Mobile Release
- **Web App**: [https://ompc-ballistic-aerodata.web.app](https://ompc-ballistic-aerodata.web.app)
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
    { name: 'OMPC_Ballistic_AeroData.apk', path: 'build\\app\\outputs\\flutter-apk\\app-release.apk' }
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
