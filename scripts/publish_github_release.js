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
const TAG_NAME = 'v1.8.1';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.8.1 (14 Key Ballistic Quality & Reporting Enhancements)';
const BODY = `## OMPC Ballistic AeroData v1.8.1

Comprehensive release delivering all 14 requested enhancements across ballistic testing, quality reporting, and statistical process control.

### Summary of Completed Enhancements:
1. **EPVAT Report Auto-Calculation Restoration**: Restored full arithmetic substitution string formatting (e.g., \`3500 + 5 * 100 = 4000 bar\`) with auto-calculation in exported HTML and Word reports.
2. **Waterproof Retest Sampling Location**: Enabled inspectors to select standard locations or enter custom sampling locations during waterproof retest execution.
3. **Print Header & Footer Suppression**: Suppressed browser print headers and footers (document title, timestamp, and local URL) during Final Lot Acceptance Certificate printing.
4. **Unified Reference Numbering**: Standardized test and certificate reference counters across all modules starting at \`REF:01\`.
5. **Adaptive SPC Parameters**: SPC visualization on the Dashboard automatically defaults to appropriate metrics based on the chosen test:
   - Waterproof Test: Single chart for Total Leaks.
   - Extraction Force Test: Single chart displaying Mean, Min, Max, and SD simultaneously.
   - Function Test: Single chart for Total Defects.
   - Residual Stress Test: Single chart for Total Splits.
   - Firing Rate: Single chart for Cyclic Rate (RPM).
   - Primer Sensitivity: Single chart for Mean Height H̄ (mm).
6. **Default Startup Module**: Set default startup module to "Daily Test".
7. **Certificate Module Isolation**: Restricted Final Lot Acceptance Certificate and Lot Dossier exports strictly to the Lot Acceptance module.
8. **Dedicated Component Report Templates**: Implemented specialized report layouts and headers for Component Acceptance testing (Primer and Propellant).
9. **Multi-Formula EPVAT Rules in Control**: Admin can configure and evaluate multiple custom formulas per temperature (+21 °C, +52 °C, -54 °C).
10. **Removed Hardcoded EPVAT Tolerances from Log Entry**: Removed hardcoded velocity tolerance and max pressure overrides, suppressing advisory spec cards for EPVAT and Propellant tests.
11. **Inspection Log Vertical Clearance**: Shifted recommendations, remarks, and signatures up by 1.5 inches to provide ample physical signature space.
12. **Open Report Without Saving**: Added "Open Report Without Saving" button in Log Entry allowing preview/opening in a new window without database submission.
13. **Executive Test-Level SPC & Box-Whisker Analytics**: Redesigned Executive Reports to filter by Test rather than individual parameters, generating SPC and Box & Whisker distribution plots for each test.
14. **Organized Lot Acceptance Certificate Layout**: Formatted table alignment, typography, and status cards to achieve complete parity with reference Word documentation on single A4 portrait.
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
    { name: 'OMPC_Ballistic_AeroData_v1.7.2.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.7.2.apk' },
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
