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
const TAG_NAME = 'v2.0.5';
const RELEASE_NAME = 'OMPC Ballistic AeroData v2.0.5 (Executive Report Hierarchy, Daily Test Performed Date Order, Vertically Stacked SPC Charts, Primer 5.56 Lot Sync, Weapon State Reset)';
const BODY = `## OMPC Ballistic AeroData v2.0.5

Ballistic analytics and inspection intelligence release introducing complete executive report hierarchy restructuring, chronological inspection ordering by performance date, vertically stacked SPC analysis, dynamic hopper terminology for daily testing, seamless primer component cross-referencing, and state isolation:

### Key Enhancements & Features:
1. **Daily Test Inspection Log Ordering & Display**:
   - The Inspection Log now prominently displays the actual test performance date and time (\`testTime\`) selected during log entry rather than the submission timestamp.
   - All inspection records across Daily Test are sorted descending by date/time performed so users immediately see the most recent real-world test activity.
2. **Executive Report Hierarchical Structure**:
   - **Part 1: Lot Acceptance**: Sub-divided strictly by Caliber specifications, with individual Lot Numbers and their respective test results presented independently, followed by caliber-level SPC trend and Box & Whisker analysis.
   - **Part 2: Daily Test**: Sub-divided by Caliber specifications with hoppers grouped together, followed by caliber-level SPC trend and Box & Whisker analysis.
   - **Part 3: Component Test**: Structured with dedicated sub-sections for propellants and primer sensitivity.
   - Module inclusion checkboxes allow selective generation of any combination of modules.
3. **Weekly Period Analysis**:
   - Added full support for 'Weekly' aggregation in both the UI dashboard and Executive HTML / Tabular report exports (Monday to Sunday calendar window), alongside Daily, Monthly, and Yearly.
4. **Executive Report Dashboard UI**:
   - Completely mirrors the executive report export hierarchy in the in-app Executive Reports tab, with embedded interactive Trend Line and Box & Whisker charts per caliber.
5. **Primer 5.56 Lot Synchronization & Family Equivalence**:
   - Primer lots submitted in the Component module are fully discoverable and selectable when creating a primer report in Lot Acceptance for any 5.56 caliber lot.
   - Implemented bidirectional caliber equivalence families: \`5.56\` & \`.223\`, \`7.62\` & \`.308\`, \`9mm\` & \`9x19\`.
6. **Daily Test Dashboard SPC Terminology ("Hopper")**:
   - Updated the Daily Test SPC matrix controls and labels from "Lot" to "Hopper" (\`By Hopper No.\`), reserving the term "Lot" exclusively for Lot Acceptance and Component modules.
7. **Vertically Stacked SPC Multi-Test Layout**:
   - When multiple test types are selected in the SPC Matrix, charts are stacked vertically (top/bottom) instead of horizontally (left/right side-by-side) to maximize resolution, trend readability, and detail.
8. **Lot Acceptance Primer Entry Form Clean State**:
   - Result fields and remarks remain clean/empty upon selecting a caliber until the user explicitly selects a lot number and inputs remarks.
9. **Weapon State Isolation & Round Count Validation**:
   - Weapon selections and firing counts are cleanly reset on logout and when opening the Function Test dialog.
   - Explicit weapon serial and round count entry is strictly enforced with user feedback.
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
    { name: 'OMPC_Ballistic_AeroData_v2.0.5.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v2.0.5.apk' },
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
