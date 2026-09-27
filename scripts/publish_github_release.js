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
const TAG_NAME = 'v1.5.7';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.5.7 (Retest Parameter Pre-filling, Retest Remarks, Multi-Platform Releases)';
const BODY = `## OMPC Ballistic AeroData v1.5.7

Major release introducing automated retest parameter pre-filling, editable retest remarks, multi-platform releases (Windows, Android APK, Web), and complete cloud synchronization:

### Key Highlights & Features:
1. **Automated Retest Parameter Pre-filling**:
   - All parameters from the original inspection report are automatically pre-populated when executing a retest across all 9 test types:
     - **Waterproof**: Sample Qty, Total Leaks, Mouth Slow/Fast, Primer Slow/Fast.
     - **Residual Stress**: Sample Qty, Total Splits, Room Temp, Neck/Shoulder/Body/Head Slow & Fast.
     - **Extraction Force**: Sample Qty, Min Force (N), Mean Force (N), Force Type.
     - **Accuracy & Velocity**: Sample Qty, Mean Radius, Largest Dist, SD X/Y, Mean/Min/Max/SD Velocity.
     - **EPVAT / Propellant**: Sample Qty, Cartridge Temp, Action Time Mean, P1 Mean/Max/Min/SD, P2 Mean/Max, Velocity Mean/SD.
     - **Function**: Sample Qty, Temp, Defect Details, Level 1–4 defects count.
     - **Primer Sensitivity**: Sample Qty, Mean Height H̄, SD S, Min All-Fire H, Max No-Fire H.
     - **Firing Rate Cycle**: Weapon Category, Cyclic Rate (RPM).
     - **Terminal Effect**: Hole Diameter, Steel Penetration, Velocity.
   - Inspectors can modify any parameter if retest values deviate from the initial run.
2. **Dedicated Retest Remarks & Findings Area**:
   - Multi-line textarea for capturing detailed retest findings, observations, and reasons for disposition.
   - Outcome selector with 3 statuses: \`Approved (Retest Passed)\`, \`Approved with condition\`, \`Rejected (Retest Failed)\`.
   - Automatic audit trail stamped: \`[RETEST by <inspector> on <timestamp> - Outcome: <status>]: <remarks>\`.
3. **Comprehensive Report & Export Integration**:
   - Formatted multiline remarks with \`white-space: pre-wrap\` preserved across HTML, PDF, and Word reports.
   - Full remarks columns added to Excel CSV exports across all test modes including Waterproof and Residual Stress.
4. **Supabase Cloud Synchronization & Zero Data Loss**:
   - Schema-safe serialization ensures retest metadata is safely embedded into notes if dedicated columns are absent.
   - Guaranteed zero data loss across local and remote Supabase tables.
5. **Multi-Platform Deployment (Windows, Android APK, Web)**:
   - **Android APK**: \`OMPC_Ballistic_AeroData.apk\` & \`OMPC_Ballistic_AeroData_v1.5.7.apk\` compiled with Android SDK 36.
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
    { name: 'OMPC_Ballistic_AeroData_v1.5.7.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.5.7.apk' },
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
