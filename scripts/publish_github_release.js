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
const TAG_NAME = 'v1.7.0';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.7.0 (Witness Storage Module, Complete Lot Dossier, EPVAT Order & Retest Tables)';
const BODY = `## OMPC Ballistic AeroData v1.7.0

Major release introducing the Witness Storage module with automated quantity countdown, Complete Lot Dossier compilation in strict sequence, standardized Final Lot Acceptance Certificate exports, EPVAT test specification reordering, and serial tracking across consumables.

### Key Enhancements & Features:
1. **New Witness Storage Module**:
   - Registered under dedicated navigation with role-based access for technicians, inspectors, and administrators.
   - Comprehensive lot registration: Caliber, Lot Number, Initial Quantity, Powder Details (Lot, Supplier, Type, Charge Weight), Primer Details (Lot, Supplier, Type), and Storage Location.
   - Consumption logging with validation, testing purpose/order reference, and operator tracking.
   - Real-time automated countdown with dynamic status indicators (\`ACTIVE\`, \`LOW STOCK\`, \`DEPLETED\`).
   - Dual-layer synchronization supporting local storage and cloud Supabase tables (\`witness_storage_lots\` & \`witness_storage_consumptions\`).

2. **Complete Lot Dossier (Word & PDF Export)**:
   - Exports the complete suite of tests for any lot in one unified document in exact sequence:
     1. Final Lot Acceptance Certificate
     2. Waterproof Test
     3. Extraction Force Test
     4. Accuracy Test
     5. EPVAT test
     6. Function Test
     7. Residual Stress Test
     8. Primer Sensitivity Test
   - Available via 1-click "Complete Dossier (Word)" and "Complete Dossier (PDF)" actions in the Inspection Log.

3. **Final Lot Acceptance Certificate**:
   - Renamed default export title and report banners from "Combined Test Report" to "Final Lot Acceptance Certificate".
   - Key Results / Metrics column synchronized with the Inspection Log display format (e.g. \`Test: 4 leaks / Retest: 0 leak\`).

4. **EPVAT Test Reordering**:
   - Single-temp round rows and auto-calculated statistics ordered as: **P1 (Chamber)**, **P2 (Port)**, **Action Time**, **Velocity**.
   - Standardized across Log Entry UI and exported HTML/Word/PDF reports.

5. **Primer Sensitivity Mean Height (H̄)**:
   - Added Mean Height (H̄) column immediately preceding SD in exported tables.

6. **Retest Tables & Reference Number Counters**:
   - Retest verification tables styled with matching \`data-table\` layout and numbered sequentially (\`Retest 1\`, \`Retest 2\`, etc.).
   - Added test Reference Number counter to the top-right report header (\`Ref No: REF-XXXX\`).
   - Transparent defect and sample size summation across initial tests and retests.

7. **Barrels & Transducers Serial Number Management**:
   - Admins can register serial numbers for Barrels and Pressure Transducers.
   - Users select which active serial number was consumed during testing, recorded in consumption history.

8. **Database & Cross-Platform Packaging**:
   - Updated \`supabase_tables_setup.sql\` with dedicated \`witness_storage_lots\` and \`witness_storage_consumptions\` tables with RLS and public policies.
   - Full 57-test suite passing with 0 errors.
   - Available for Web (Firebase), Windows Desktop (Installer, Standalone, Portable ZIP), and Android APK.
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
    { name: 'OMPC_Ballistic_AeroData_v1.7.0.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.7.0.apk' },
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
