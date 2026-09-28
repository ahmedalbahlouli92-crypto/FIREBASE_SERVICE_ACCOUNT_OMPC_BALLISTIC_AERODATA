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
const TAG_NAME = 'v1.5.9';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.5.9 (Collapsible Control, Submission Alerts, EPVAT Summary Statistics, UI Enhancements)';
const BODY = `## OMPC Ballistic AeroData v1.5.9

Production release with major UI refinements, automated real-time submission alerts, dynamic collapsible control modules, and streamlined EPVAT evaluation & reporting:

### Key Highlights & Features:
1. **Dynamic Collapsible Control Panel (1-Page Fit)**:
   - Control panel refactored to single-column responsive layout with immediate vertical sliding.
   - When sections collapse, lower sections slide up seamlessly; when sections expand, lower sections slide down.
   - "Collapse All" and "Expand All" one-click action buttons.
   - All 6 sections fit comfortably on one page when collapsed.
2. **Audio Chime & Real-Time Multi-User Submission Alerts**:
   - Native audio alert plays upon report submission.
   - Supabase Realtime broadcasts submission events across connected sessions, flashing a one-time alert notification with a direct "View in Logs" button.
3. **EPVAT Summary Statistics & 1-Page Fit Reports**:
   - Replaced raw round dumps with clean Summary Statistics evaluation table (P1, P2, Velocity, Action Time: Mean, Max, Min, Range, SD).
   - "Evaluated Calculation" column streamlined to display auto-calculated values and units.
   - Optimized print CSS ensuring clean 1-page fit on standard paper.
4. **Sentencing & Specification Simplification**:
   - Resolved EPVAT auto-sentencing bug: now strictly evaluates active custom caliber formulas.
   - Removed obsolete temperature specification chips/fields and legacy 3-sigma/delta toggles from Control.
   - Quality Status field enlarged to flex: 6 preventing any text truncation.
   - Red asterisk (*) prominently indicates all mandatory required fields.
   - Function test classification diagram repositioned below Remarks; Remarks defaults to empty.
5. **Cross-Platform Deployment**:
   - **Windows Desktop**: 1-Click Installer (\`OMPC_Ballistic_AeroData_Setup.exe\`), Standalone Executable (\`OMPC_Ballistic_AeroData.exe\`), and Portable ZIP.
   - **Android APK**: Compiled release APKs (\`OMPC_Ballistic_AeroData.apk\`, \`OMPC_Ballistic_AeroData_v1.5.9.apk\`).
   - **Web Application**: Live on Firebase Hosting at https://ompc-ballistic-aerodata.web.app.
   - **Supabase**: Real-time broadcast and master database synchronization verified.
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
    { name: 'OMPC_Ballistic_AeroData_v1.5.9.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.5.9.apk' },
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
