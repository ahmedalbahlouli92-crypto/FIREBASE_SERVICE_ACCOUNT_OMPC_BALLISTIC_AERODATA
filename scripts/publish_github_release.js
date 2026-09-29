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
const TAG_NAME = 'v1.6.2';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.6.2 (Window-Fitting Inspection Log, PDF Filename Format, Non-Destructive Retests & Supabase Sync)';
const BODY = `## OMPC Ballistic AeroData v1.6.2

Comprehensive release delivering a fully responsive Inspection Log table layout, standardizing PDF export naming conventions, introducing non-destructive retest separation across logs and reports, updating the Supabase schema and serialization, and expanding cross-platform packaging.

### Key Enhancements & Fixes:
1. **Inspection Log Table Responsive Overhaul (Zero Horizontal Scrolling)**:
   - Replaced rigid horizontal-scrolling \`DataTable\` with a responsive, proportional flex-column layout.
   - Fits seamlessly within 100% of the active window width without requiring horizontal scrollbars.
   - Pinned table header with clear column weights, high-contrast typography, and compact action icon buttons.
   - Hover tooltips for quick preview of complete notes and test details.

2. **Default PDF Filename Convention**:
   - PDF export default filename format standardized to: \`[Caliber]_[Test Name]_[Lot number].pdf\` (e.g., \`7.62x51mm_EPVAT_LOT-2026-A.pdf\`).
   - Clean filename sanitization removing characters incompatible with Windows and Android file systems.

3. **Non-Destructive Retest Separation**:
   - Retest records and statistics are separated cleanly from initial test runs.
   - Retest telemetry is preserved non-destructively in exported reports and history records.

4. **Remarks & Defect Classification Reference Guide Formatting**:
   - Standardized 210px matching box heights across remarks and defect classification reference guides.
   - Removed placeholder text and auto-generated remarks from exported HTML/Word/PDF reports for clean, audit-ready presentation.

5. **Full Admin Edit Authority**:
   - Granted full editing authority across all test parameters and metadata for administrative users.

6. **Supabase Database Schema & Serialization Synchronization**:
   - Updated \`supabase_tables_setup.sql\` with retest columns (\`retest_produced\`, \`retest_defects\`, \`retest_metrics\`).
   - Safe dual-layer fallback serialization via \`[RETEST|...|prod:...|def:...|met:...]\` tag ensuring full backward and forward compatibility with Supabase without PGRST204 column errors.

7. **Cross-Platform Deployments**:
   - **Web Application**: Live on Firebase Hosting at https://ompc-ballistic-aerodata.web.app.
   - **Windows Desktop**: 1-Click Setup Installer (\`OMPC_Ballistic_AeroData_Setup.exe\`), Standalone Executable (\`OMPC_Ballistic_AeroData.exe\`), and Portable ZIP (\`OMPC_Ballistic_AeroData_Portable.zip\`).
   - **Android APK**: Updated release APK (\`OMPC_Ballistic_AeroData_v1.6.2.apk\` and \`OMPC_Ballistic_AeroData.apk\`).
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
    { name: 'OMPC_Ballistic_AeroData_v1.6.2.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.6.2.apk' },
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
