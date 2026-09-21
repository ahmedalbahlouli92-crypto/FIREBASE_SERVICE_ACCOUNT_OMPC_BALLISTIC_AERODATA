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
1. **PC Auto-Update & Immediate Logout Fix**:
   - Eliminated the false "Update Published" popup loop and premature session reset.
   - Suppressed legacy Windows 7 & 8 Microsoft Edge unsupported browser banners via Chromium flags.
2. **Android Release APK Cloud Sync & Registered Users**:
   - Added missing \`android.permission.INTERNET\` and \`android.permission.ACCESS_NETWORK_STATE\` to release APK manifest.
   - All cloud-registered laboratory personnel, admin rules, and test records now synchronize seamlessly across mobile and all PCs.
3. **EPVAT ± (Plus-Minus) Tolerance Calculations**:
   - Added full support for \`±\` and \`+/-\` operators in mathematical formula evaluation, arithmetic substitution, and administrative formula definitions.
   - Evaluates range-bound acceptance criteria (\`abs(x - target) <= tol\`).
4. **Strict Submission Validation Across All 9 Test Types**:
   - Comprehensive required-field checks on all ballistic and mechanical tests.
   - Blocks submission if required test fields are empty and automatically jumps to missing fields.
5. **Action Time 2-Digit Input Formatter**:
   - Enforces \`^\\d{0,2}(\\.\\d{0,3})?$\` across all action time inputs.
6. **Supabase Cloud Database Cross-PC Synchronization**:
   - Automatic retry and robust connection handling across all platforms.
7. **Android Layout & Responsive Screen Adjustments**:
   - Redesigned mobile AppBar with a compact dropdown, clock badge, and consolidated profile & options \`PopupMenuButton\`.
8. **Windows Desktop Auto-Hiding Modules Sidebar**:
   - Animated sidebar that smoothly collapses when moving to main content, taking 100% full screen.

### Binaries & Deployments:
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
