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
const TAG_NAME = 'v1.4.0';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.4.0 (Enhanced QC, EPVAT Multi-Temp, SPC Export, Minimize Support & Consumables)';
const BODY = `## OMPC Ballistic AeroData v1.4.0

### Key Updates & New Features:
1. **Waterproof Caliber Exclusion**:
   - Excluded Waterproof Test option for \`.223 69 grains\`, \`.223 55 grains\`, \`.223 77 grains\`, \`7.62x51 .308\`, \`9mm Match\`, and \`9mm Luger\`.
2. **Editable Primer Sensitivity HM & SD**:
   - Operators can now directly enter Bruceton \`HM\` and \`SD\` parameters. The system automatically computes All Fire ($\\bar{H} + 5S$), No Fire ($\\bar{H} - 2S$), and evaluates sentencing against specifications.
3. **Streamlined Evaluation Rules**:
   - Removed GP Transducers, Barrels, and Weapons from the Evaluation Rules dropdown to focus strictly on ballistic and mechanical inspection requirements.
4. **Formula & Input Focus Stability**:
   - Fixed formula editor text loss / unfocus bug by using permanent keys on dynamic input fields.
5. **Enlarged High-Visibility Branding**:
   - Enlarged OMPC logos across the splash screen (120px), login modal (150px), and navigation sidebar (68px).
6. **Centered Welcome Access Modal**:
   - Implemented an access-granted modal dialog in the center of the screen upon authentication.
7. **Default Waterproof Sample Size**:
   - Defaulted Waterproof Test sample size to 20 rounds (editable by operators).
8. **EPVAT Multi-Temperature Testing Workflow**:
   - Integrated \`Single Temperature\` vs \`All 3 Temperatures (+21°C, +52°C, -54°C)\` segmented workflow identical to Function Test.
9. **Statistical Process Control (SPC) Trend Export**:
   - Added Test Type dropdown filter with dynamic parameter population and an **Export Trend Report** button generating print-ready reports with Grand Mean, Grand SD, Control Limits (UCL/LCL), and group breakdown tables.
10. **M193 Velocity Distance Persistence**:
    - Defaulted velocity distance for M193 to 21m and preserved it across test submission and field reset.
11. **Window Minimize Support**:
    - Windows standalone executable now allows minimizing the application to the taskbar without shutting down or terminating the background server.
12. **Blank Caliber Cyclic Rate Testing**:
    - Enabled cyclic rate testing and admin evaluation limits for blank calibers (5.56 M200 Blank and 7.62 M82 Blank).
13. **Full Consumable Items Management Module**:
    - Complete stock management with item registration, restock (auto count-up), user consumption (auto count-down), transaction history logs, and two-way Supabase Cloud synchronization.
14. **Android APK Release**:
    - Compiled standalone Android APK (\`OMPC_Ballistic_AeroData_v1.4.0.apk\`).

### Binaries & Deployments:
- **Web Portal**: [https://ompc-ballistic-aerodata.web.app](https://ompc-ballistic-aerodata.web.app)
- **Android APK**: \`OMPC_Ballistic_AeroData.apk\`
- **Windows Setup**: \`OMPC_Ballistic_AeroData_Setup.exe\`
- **Windows Portable**: \`OMPC_Ballistic_AeroData_Portable.zip\`
- **Standalone EXE**: \`OMPC_Ballistic_AeroData.exe\`
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
    { name: 'OMPC_Ballistic_AeroData_v1.4.0.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.4.0.apk' },
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
