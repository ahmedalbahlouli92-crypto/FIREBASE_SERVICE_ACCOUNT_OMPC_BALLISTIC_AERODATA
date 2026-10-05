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
const TAG_NAME = 'v1.9.2';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.9.2 (EPVAT Auto-Calc Lock, Admin Controls & Editing, SPC Multi-Param Charts, Scoped Certificates & Supabase Sync)';
const BODY = `## OMPC Ballistic AeroData v1.9.2

Comprehensive release implementing EPVAT automated formula locking, Admin sampling location management & test editing, SPC multi-parameter overlay charts, caliber-scoped Lot Acceptance Certificates, and database schema updates:

### Key Enhancements & Features:
1. **EPVAT Test Auto-Calculation & Status Lock**:
   - EPVAT overall status is strictly and automatically determined by formula evaluation across all temperatures (+21 °C, +52 °C, -54 °C).
   - "Approved" if all formulas pass; "Rejected" if any formula fails. Manual status overriding is locked.
2. **Admin Sampling Locations Control**:
   - Administrators can add, rename, and delete sampling locations with real-time bidirectional synchronization between Supabase and local storage.
3. **Admin Test Data Editing**:
   - Comprehensive editor for all ballistic tests: EPVAT multi-temperature parameters (Chamber P1, Port P2, Velocity, Action Time), Primer sensitivity with live HM+5SD and HM-2SD calculations, Accuracy X & Y variables, and defect quantities.
4. **SPC Multi-Parameter Same-Chart Overlay**:
   - Users can select multiple parameters from the same test simultaneously (e.g. Primer Sensitivity HM+5SD and HM-2SD).
   - Dynamically graphs multi-curve series on a unified Y-axis scale with distinct series colors, value chips, and an in-chart legend.
5. **Lot Acceptance Inspection Log Clean Up**:
   - Completely removed Hopper No. from search placeholders, filter chips, and table columns in the Lot Acceptance module, retaining only Lot Number.
6. **Certificate Sample Size Accuracy**:
   - Sample size on the Lot Acceptance Certificate accurately reflects the actual sample sizes tested for each test record.
7. **Strict Certificate Table Ordering**:
   - Test tables in both the Certificate and Lot Dossier strictly follow the required sequence:
     1. Waterproof Test
     2. Bullet Extraction (Extraction Force Test)
     3. Accuracy Test
     4. EPVAT test (+21 °C, +52 °C, -54 °C)
     5. Function Test
     6. Residual Stress Test
     7. Terminal Effect Test
     8. Primer Sensitivity Test
8. **Certificate Filtering by Lot & Caliber**:
   - Users select Caliber Specification and Lot Number; certificate results and calculations are scoped strictly to the selected lot and caliber.
9. **Supabase Database Schema Setup**:
   - Updated \`supabase_tables_setup.sql\` with all 20 test tables, 8 consumable category tables, witness storage tables, equipment issues, admin control tables, and dedicated EPVAT multi-temperature columns.
10. **Firebase Cloud Web Deployment**:
    - Compiled and deployed live to Firebase Hosting: \`https://ompc-ballistic-aerodata.web.app\`.
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
