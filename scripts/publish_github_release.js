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
const TAG_NAME = 'v1.9.0';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.9.0 (13 Ballistic System Enhancements: Admin Sampling Locations, SPC Matrix, Edit Authority & Edge Suppression)';
const BODY = `## OMPC Ballistic AeroData v1.9.0

Major release implementing 13 core ballistic quality, statistical process control, and system enhancements:

### Key Enhancements & Features:
1. **Admin Sampling Locations Management**:
   - Quality Administrators can dynamically Add, Edit/Rename, or Delete sampling locations directly in the Admin Control tab.
   - Preserves both standard industrial presets (Lines 1-6, QA Lab, Hopper Machine, Assembly Line, etc.) and custom locations.
2. **Retest Sampling Location Dropdown**:
   - Converted Retest dialog sampling location into a dynamic dropdown populated with all system sampling locations (including custom added locations).
   - Retest location is now persisted for all test types upon retest submission.
3. **EPVAT Rules & Status Decoupling**:
   - Decoupled attached advisory spec rules / admin recommendations from the final status in Lot Entry and Inspection Log.
   - Manual status overrides are strictly respected and preserved when calculations pass.
4. **Admin Full Record Edit Authority**:
   - Quality Administrators have unrestricted authority to edit any field of submitted records (Test Protocol, Caliber, Timestamp, Test Time, Sampling Location, all Test Metrics, Retest Metrics, Status, and Notes).
5. **Dashboard Test-First SPC Matrix**:
   - Dashboard Statistical Process Control chart now enforces selecting a Test Type first.
   - Shows an intuitive guidance message until a test is selected; no parameters appear beforehand.
6. **Test-Specific SPC Metrics**:
   - **Waterproof Test**: Total Fast Leaks, Total Slow Leaks, Total Leaks.
   - **Accuracy Test**: Average SD (X & Y), Mean Radius, SD X, SD Y.
   - **EPVAT Test**: All EPVAT parameters selectable.
   - **Residual Stress Test**: Number of cracks / total splits.
   - **Primer Sensitivity Test**: HM+5SD and HM-2SD.
   - **Function Test**: Level 1, 2, 3, 4 Defects, and Total Defects.
7. **Multi-Parameter Selection Filter**:
   - Strict test-level filtering with support for selecting up to 4 parameters/charts simultaneously.
8. **Admin Control "Approved with Condition" Field**:
   - Dedicated configuration field under Admin Rules allowing quality managers to set specific criteria for conditional approvals across all ballistic tests.
9. **Waterproof 0 to 3 Leaks Sentenced as "Approved"**:
   - Waterproof tests with 0 to 3 leaks are automatically sentenced as "Approved" (instead of "Approved with condition").
10. **Instant Report Opening Without Saving**:
    - Added instant "Open Report (No Save)" and "Open Dossier (No Save)" actions in report dialogs. Opens inspection documents in-memory via temporary blob/file without requiring download or local disk save.
11. **Edge Deprecation Warning Permanent Suppression**:
    - Automated suppression of the Windows notification banner (*"Microsoft edge is no longer supported on this version of windows..."*) across client PCs via registry policies and browser startup arguments.
12. **Firebase Cloud Web Deployment**:
    - Compiled and deployed live to Firebase Hosting: \`https://ompc-ballistic-aerodata.web.app\`.
13. **Supabase Cloud Sync & GitHub Publication**:
    - Complete cross-platform sync and GitHub distribution with 1-Click Setup Installer and Portable Zip.
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
