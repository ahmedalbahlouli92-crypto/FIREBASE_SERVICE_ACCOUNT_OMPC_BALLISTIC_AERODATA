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
const TAG_NAME = 'v1.4.2';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.4.2 (3-Digit Lot Validation, GP1/GP2 9mm Chamber Isolation, Dynamic Pressure Unit Auto-Conversion, Cartridge Reference Diagrams & Admin Weapon Registry)';
const BODY = `## OMPC Ballistic AeroData v1.4.2

### Key Updates & Enhancements:
1. **3-Digit Lot & Hopper Validation with Year Dropdowns**:
   - Strictly enforces 3-digit validation ("Please add three digits") for Lot and Hopper numbers.
   - Replaced manual year inputs with standardized dropdown selectors covering 2016–2035.
2. **GP1 (Chamber) & GP2 (Port) Standardization & 9mm Chamber Isolation**:
   - Re-labeled ballistic pressure metrics to GP1 (Chamber) and GP2 (Port).
   - GP2 (Port) pressure fields and statistics are completely hidden across entry inputs, statistics, and generated HTML/Word reports for all 9mm calibers.
3. **EPVAT Pressure Unit Dynamic Auto-Conversion**:
   - Toggling pressure units (bar, MPa, kg/cm²) automatically converts individual round inputs, statistics, and formula limit thresholds in real-time.
4. **EPVAT Formula Differentiation (Single-Temp vs 3-Temp Modes)**:
   - Specific single-temp formula evaluation versus multi-temperature tolerance calculations.
   - Enforced single-temperature mode for .223, .308, 9mm Luger, and 9mm Match calibers.
5. **Locked Test Time**:
   - Initial test time remains locked upon opening without auto-ticking timer, with manual picker and refresh support.
6. **Cartridge Classification Reference Diagrams**:
   - Visual reference diagrams integrated for Residual Stress and Function tests in both Log Entry and exported reports.
7. **Admin Weapon Registration**:
   - Weapon category selection with cascaded manufacturer dropdown, model, and serial number registration.
8. **Welcoming Greeting & APK Auto-Update**:
   - Time-based "Alsalamu Alaikum" badge and welcome dialog on session start.
   - Automatic GitHub Release APK update check and direct download prompt.
9. **Blank Caliber Function Test Cold Temperature**:
   - M82 and M200 blanks default cold test temperature to -32 °C.
10. **UI & Layout Optimizations**:
    - Sidebar logo enlarged x2 (136px).
    - Log Entry form converted to 100% full width.

### Binaries & Deployments:
- **Android APK**: \`OMPC_Ballistic_AeroData_v1.4.2.apk\`
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
    { name: 'OMPC_Ballistic_AeroData_v1.4.2.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.4.2.apk' },
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
