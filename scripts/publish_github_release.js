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
const TAG_NAME = 'v1.5.8';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.5.8 (Quality Status Visibility, EPVAT Ordering, Primer Sensitivity Limits, Reporting Fixes)';
const BODY = `## OMPC Ballistic AeroData v1.5.8

Quality & ballistic lab release delivering UI visibility improvements, EPVAT ordering updates, Primer Sensitivity limits and auto-calculation, and multi-platform deployment (Windows, Android APK, Web):

### Key Highlights & Enhancements:
1. **Quality Status Visibility**:
   - Enlarged Quality Status field with dynamic text scaling (\`FittedBox\`) and increased flex allocation, ensuring \`Approved with condition\` displays fully without truncation across all screens.
2. **Exported Reports (PDF, Word, Excel)**:
   - Initial Test and Retest results are clearly separated in all exported reports (HTML/PDF, Word, and CSV/Excel), including retest operator, timestamp, and audit notes.
3. **EPVAT Parameter & Round Ordering**:
   - Moved **Action Time (ms)** before **Velocity (m/s)** across EPVAT 3-temperature cards, individual round tables, summary statistics, and all exported reports.
4. **Admin Formulas & Multi-Temp Persistence**:
   - Fixed variable extraction and formula normalization for multi-temperature EPVAT tests so calculated formula evaluations persist correctly into submitted records and reports without zeroing out.
5. **EPVAT Export Formatting**:
   - Cleaned up temperature strings, removed unprintable unicode artifacts and HTML entities (&deg;C), matching the clean log entry interface.
6. **Inspection Log Layout Improvements**:
   - **Accuracy Test**: 3-line stacked layout displaying SD X result on top, SD Y result below it, and Mean Velocity on the bottom.
   - **EPVAT Test**: 3-line stacked layout displaying Mean Chamber pressure on top, Mean Port pressure below it, and Mean Velocity (+21 °C) on the bottom.
7. **Primer Sensitivity Caliber Rules & Auto-Calculation**:
   - **Caliber 7.62**: $\\bar{H} + 5S < 500$ and $\\bar{H} - 2S > 75$
   - **Caliber 5.56**: $\\bar{H} + 5S < 450$ and $\\bar{H} - 2S > 75$
   - **Caliber 9mm**: $\\bar{H} + 5S < 350$ and $\\bar{H} - 2S > 75$
   - Manual entry of $\\bar{H}$ and $SD$ auto-calculates limits and updates status (\`Approved\` / \`Rejected\`).
   - Removed obsolete drop ball weight and misfires fields.
   - Removed redundant Primer Lot Number field from Component Primer Specifications.
8. **Multi-Platform Deployment (Windows, Android APK, Web)**:
   - **Android APK**: \`OMPC_Ballistic_AeroData.apk\` & \`OMPC_Ballistic_AeroData_v1.5.8.apk\`.
   - **Windows Desktop**: 1-Click Setup Installer (\`OMPC_Ballistic_AeroData_Setup.exe\`), Standalone Executable (\`OMPC_Ballistic_AeroData.exe\`), and Portable Archive (\`OMPC_Ballistic_AeroData_Portable.zip\`).
   - **Web Application**: Live on Firebase Hosting at https://ompc-ballistic-aerodata.web.app.
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
    { name: 'OMPC_Ballistic_AeroData_v1.5.8.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.5.8.apk' },
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
