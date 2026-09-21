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
const TAG_NAME = 'v1.4.1';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.4.1 (Supabase Cross-PC Sync, EPVAT ± Formula, Strict Field Validation, 2-Digit Action Time, Responsive Mobile UI & Windows Auto-Hide Sidebar)';
const BODY = `## OMPC Ballistic AeroData v1.4.1

### Key Updates & Enhancements:
1. **EPVAT ± (Plus-Minus) Tolerance Calculations**:
   - Added full support for \`±\` and \`+/-\` operators in mathematical formula evaluation, arithmetic substitution, and administrative formula definitions.
   - Evaluates range-bound acceptance criteria (\`abs(x - target) <= tol\`).
2. **Strict Submission Validation Across All 9 Test Types**:
   - Comprehensive required-field checks on all ballistic and mechanical tests (EPVAT, Waterproof, Extraction, Accuracy, Residual Stress, Function, Firing Rate, Terminal Effect, Primer Sensitivity).
   - Blocks submission if required test fields are empty and automatically jumps to missing fields.
3. **Action Time 2-Digit Input Formatter**:
   - Enforces \`^\\d{0,2}(\\.\\d{0,3})?$\` across all action time inputs (accepts \`00.000\`, \`1.5\`, \`12.345\`; rejects 3 or more digits before decimal).
4. **Supabase Cloud Database Cross-PC Synchronization**:
   - Resolved cold-boot connection timeouts by adding robust \`ensureInitialized()\` and increasing initial connection timeout to 15s.
   - Implemented bidirectional sync in \`StorageService\` that merges cloud records with local desktop CSV records and pushes unsynced offline records to Supabase in the background.
5. **Android Layout & Responsive Screen Adjustments**:
   - Redesigned mobile AppBar with a compact dropdown, clock badge, and consolidated profile & options \`PopupMenuButton\`, completely eliminating pixel overflow on Android devices.
   - Made dialogs adaptive with \`math.min(width, screenWidth * 0.94)\` and added horizontal scrolling to EPVAT round tables.
6. **Windows Desktop Auto-Hiding Modules Sidebar**:
   - Animated sidebar that smoothly collapses to width 0 when the cursor moves into the main content, allowing the dashboard, log entry, and inspection screens to take 100% full screen.
   - Hovering near the left edge smoothly reveals the sidebar; includes pin/unpin header button to lock open if desired.

### Binaries & Deployments:
- **Live Web Portal**: [https://ompc-ballistic-aerodata.web.app](https://ompc-ballistic-aerodata.web.app)
- **Android APK**: \`OMPC_Ballistic_AeroData_v1.4.1.apk\`
- **Windows Setup**: \`OMPC_Ballistic_AeroData_Setup.exe\`
- **Windows Standalone**: \`OMPC_Ballistic_AeroData.exe\`
- **Windows Portable**: \`OMPC_Ballistic_AeroData_Portable.zip\`
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
    { name: 'OMPC_Ballistic_AeroData_v1.4.1.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.4.1.apk' },
    { name: 'OMPC_Ballistic_AeroData.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData.apk' }
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
