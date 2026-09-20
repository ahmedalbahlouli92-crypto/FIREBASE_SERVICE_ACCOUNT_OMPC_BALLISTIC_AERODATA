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
const TAG_NAME = 'v1.3.3';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.3.3 (Native Taskbar Grouping & Multi-User Port Isolation)';
const BODY = `## OMPC Ballistic AeroData v1.3.3

### Key Fixes & Enhancements:
1. **Native Taskbar Window Grouping (Zero Duplicate Icons)**:
   - Fixed the taskbar duplication issue where pinning the app resulted in separate unlinked browser windows. \`OMPC_Ballistic_AeroData.exe\` now hosts the application window natively with official icon and matching AppUserModelID, grouping seamlessly under the pinned taskbar icon.
2. **Multi-User & Simultaneous Session Support**:
   - Implemented strict TCP socket probing (\`ExclusiveAddressUse = true\`) across ports 8080-8200.
   - Each user session automatically binds to an isolated available port (e.g. 8080, 8081) with dedicated session profile directories, allowing multiple users and concurrent instances without collisions or browser delegation crashes.
3. **Installer Shortcut Property Integration**:
   - Enhanced shortcut creation in \`OMPC_Ballistic_AeroData_Setup.exe\` with write-mode COM property store (\`STGM_READWRITE\`) and full relaunch metadata.

### Download Binaries:
- **OMPC_Ballistic_AeroData_Setup.exe**: Windows 1-Click Installer
- **OMPC_Ballistic_AeroData.exe**: Standalone Direct Executable
- **OMPC_Ballistic_AeroData_Portable.zip**: Complete Offline Portable Package
- **OMPC_Ballistic_AeroData.apk**: Android Mobile Package
- **Live Web Application**: [https://ompc-ballistic-aerodata.web.app](https://ompc-ballistic-aerodata.web.app)
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
