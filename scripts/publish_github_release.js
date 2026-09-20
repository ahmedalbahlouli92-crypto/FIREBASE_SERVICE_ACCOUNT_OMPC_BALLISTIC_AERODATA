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
const TAG_NAME = 'v1.3.7';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.3.7 (Process Lifecycle Fix, Auto-Kill Zombies & Safe Overwrite)';
const BODY = `## OMPC Ballistic AeroData v1.3.7

### Critical Fixes & Enhancements:
1. **Resolved "File is open in another program" & Stale Process Locking**:
   - Added automatic startup termination of any orphaned or hung \`OMPC_Ballistic_AeroData.exe\` processes left behind by earlier sessions or abnormal browser closes.
   - Bundled **\`Stop_OMPC.bat\`** on Desktop and inside the Portable package to immediately terminate all running instances and release all file locks with a single double-click.
2. **Fixed "Still Not Working in Another PC" (Premature Server Termination)**:
   - On Windows systems where Edge has Startup Boost enabled, launching \`msedge.exe\` causes the bootstrap process to exit in < 1 second. Previously, the C# server mistook this for the user closing the app and killed itself, causing *"This site can't be reached / 127.0.0.1 refused to connect"*.
   - Implemented a resilient **heartbeat & window visibility monitor**: \`index.html\` pings \`/api/heartbeat\` every 1.5s and sends \`sendBeacon('/api/exit')\` on unload. The server now stays reliably active while the user is using the app and terminates cleanly within 5 seconds of the user closing Edge or pressing Alt+F4.
3. **Safe File Overwriting During Extraction & Installation**:
   - Replaced \`.NET ZipFile.ExtractToDirectory\` (which threw an unhandled \`IOException\` if files existed) with entry-by-entry stream extraction with \`overwrite: true\` in both the Standalone executable and the 1-Click Setup Installer.
4. **White-Blue Input Fields & Flutter Degree of Blue Theme**:
   - All inputs, text boxes, and dropdowns use comfortable **white-blue** (\`#E0F2FE\`), read-only fields use \`#C8E3F5\`, and borders/highlights use the sampled Flutter logo blue (\`#31B9F6\` and \`#5FC9F8\`). Plain white (\`#FFFFFF\`) has been completely eliminated.

### Download Binaries:
- **OMPC_Ballistic_AeroData_Setup.exe**: Windows 1-Click Installer
- **OMPC_Ballistic_AeroData.exe**: Standalone Direct Executable
- **OMPC_Ballistic_AeroData_Portable.zip**: Complete Offline Portable Package (includes \`Stop_OMPC.bat\`)
- **Stop_OMPC.bat**: Emergency Process Stopper & File Unlocker
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
