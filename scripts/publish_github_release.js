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
const TAG_NAME = 'v1.5.1';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.5.1 (22 Laboratory Enhancements, Executive Reports Tab & Retest Protocol)';
const BODY = `## OMPC Ballistic AeroData v1.5.1

Comprehensive release incorporating 22 laboratory quality, testing, traceability, and reporting enhancements:

### Key Highlights & Features:
1. **Admin Control & User Management**:
   - Fixed admin user modification and deletion with real-time Supabase cloud synchronization.
2. **Deduplication & Data Integrity**:
   - Eliminated duplicate submission entries in the inspection log by enforcing unique record UUIDs.
3. **Component Test Caliber & Test Type Isolation**:
   - Restricted Component Test calibers strictly to primed cases: \`5.56\`, \`7.62\`, and \`9mm\` (without military designation prefixes).
   - Component test types strictly limited to \`Primer Sensitivity\` and \`Propellant\`.
   - Entry log dynamically changes lot prompt to \`Primer Lot No.\` or \`Propellant Lot No.\`.
4. **2-Digit Hopper Number Specification**:
   - Standardized Hopper Number year prefix to exactly 2 digits (e.g., \`26\`).
5. **Primer Sensitivity Workflow Optimization**:
   - Streamlined Primer Sensitivity test by eliminating progressive round trials.
   - Added direct summary inputs: Total Rounds, Total Fire, H_Bar, Sensitivity S.D., H+3S (All Fire), and H-3S (No Fire) with automatic calculation.
6. **Inspection Log Reordering & Timestamp Accuracy**:
   - Time in inspection log reflects selected inspection time or exact submission time.
   - Column sequence standardized: \`TIME\`, \`INSPECTOR\`, \`TEST NAME\`, \`CALIBER\`, \`HOPPER NO.\` / \`LOT NO.\` / \`COMPONENT LOT\`, \`STATUS\`, \`SAMPLE SIZE\`, \`RESULTS\`, \`REMARKS\`, \`ACTIONS\`.
7. **Consumables Management (4-Column Layout)**:
   - Restructured consumable items table into 4 clean columns: \`ITEM NAME\`, \`SERIAL NUMBER\`, \`AVAILABLE STOCK\`, and \`CONSUMPTION ACTION\` (with caliber selector, quantity input, remark, and submit action).
   - Added "Received Shipment Log" dialog for receiving incoming inventory stock.
8. **QC Retest Protocol**:
   - Failed or rejected inspection log entries feature a dedicated **Retest** action.
   - Retest dialog prompts for inspector, shift, and retest remarks, linking retests back to the original test record.
9. **EPVAT Row Sequencing & Visual Quality Badge**:
   - Standardized EPVAT input rows (Row 1: Sample Size, Chamber Pressure P1, Case Mouth Pressure P2, Velocity; Row 2: Barrel Serial, Action Time).
   - Added prominent live colored Quality Status badge (Accepted / Rejected / Pending) above the test form.
10. **Analytics & SPC Enhancements**:
    - Box & Whisker plot filtered strictly to EPVAT records with metrics limited to \`Velocity SD\` and \`Pressure SD\`, plus temperature filter.
    - SPC Trend Chart equipped with dynamic time-range filter (All Time, Today, Last 7 Days, Last 30 Days, This Month, This Year).
11. **Executive Reports Module**:
    - Dedicated executive dashboard with Daily, Monthly, and Yearly aggregation periods.
    - Multi-module selection checkboxes (Daily Test, Lot Acceptance, Component Test, Consumables).
    - Summary KPI cards, interactive table previews, and instant CSV / PDF print export.
12. **Supabase Cloud Schema & Synchronization**:
    - Extended database schema in \`supabase_tables_setup.sql\` with retest tracking columns across master and dedicated tables.
    - Resilient schema fallback in \`SupabaseService\` ensuring uninterrupted cloud logging.
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
    { name: 'OMPC_Ballistic_AeroData_v1.5.1.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData.apk' },
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
