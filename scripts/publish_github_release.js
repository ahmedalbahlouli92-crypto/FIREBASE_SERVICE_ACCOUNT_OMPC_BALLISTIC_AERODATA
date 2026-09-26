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
const TAG_NAME = 'v1.5.5';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.5.5 (Caliber Barrel Registry, Inspection Log Rules, Modern Dashboard & Standalone Caliber Volume Export)';
const BODY = `## OMPC Ballistic AeroData v1.5.5

Major feature release delivering specialized laboratory quality rules, caliber-specific barrel management, inspection log result formatting, modern analytics dashboard component, standalone caliber volume exports, and dedicated Supabase admin input tables:

### Key Highlights & Features:
1. **Caliber-Specific EPVAT & Accuracy Barrel Registration**:
   - Admin Control now registers EPVAT and Accuracy barrels separately per caliber.
   - Entry Form automatically filters and prioritizes barrels assigned to the selected caliber.
2. **Standardized Inspection Log Results Formatting**:
   - Extraction force: Shows Min and Max values vertically above each other.
   - Waterproof: Shows exclusively the number of leaks.
   - Function test: Shows number of cracks and level (if 0 cracks, shows \`0 crack\`).
   - Residual stress: Shows number of cracks and zone (if 0 cracks, shows \`0 crack\`).
   - EPVAT & Propellant: Mean chamber pressure, mean port pressure, and mean velocity @ 21 °C.
   - Accuracy for 7.62, SS109, 9mm, and .223: Shows Standard Deviation (SD) of X and Y.
   - Accuracy for M193: Shows Mean Radius (MR) only.
   - Primer sensitivity: Shows HM+5SD and HM-2SD exclusively.
3. **Module & Caliber Matrix Updates**:
   - Terminal Effect Test added to Daily Test (available for SS109 in both Lot Acceptance and Daily Test).
   - Extraction Force Test disallowed for blank ammunition (M200 and M82).
4. **Intelligent Sampling Location Defaults**:
   - Lot Acceptance Test defaults to \`After Packing machine\` (user editable), except Primer Test which defaults to \`Priming machine\`.
   - Daily Test defaults to \`PC530\` for Waterproof, Extraction, EPVAT, Function, Terminal Effect, Cyclic Rate, and Residual Stress.
   - Daily Test defaults to \`PB31/14\` for Accuracy Test.
5. **Modern Dashboard Component & Standalone Caliber Volume Export**:
   - Intelligent modern dashboard component with soft icy-blue surface background (\`#edf4fc\`), sans-serif typography, vibrant sky blue accents (\`#4d99db\`), clean card containers, analytical metric boxes, and prominent action button.
   - Standalone export of Tested Caliber Volume breakdown (HTML/Print/PDF & Excel .csv) directly from the card, the modern component, or the export dialog.
6. **Dedicated Supabase Admin Control Input Tables**:
   - Added dedicated tables for all Admin Control inputs: \`admin_weapons\`, \`admin_epvat_barrels\`, \`admin_accuracy_barrels\`, \`admin_gp1_transducers\`, \`admin_gp6_transducers\`, \`admin_propellant_suppliers\`, \`admin_primer_suppliers\`, \`admin_propellant_codes\`, \`admin_function_levels\`, \`admin_sampling_locations\`, \`admin_role_permissions\`, and \`admin_test_rules\`.
   - Complete multi-table cloud sync in \`SupabaseService\` with guaranteed fallback to \`admin_control\` and zero data loss.
7. **Cleaned Testing Accounts**:
   - Deleted temporary test user accounts from Supabase and local registry while preserving all real laboratory personnel.
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
    { name: 'OMPC_Ballistic_AeroData_v1.5.5.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.5.5.apk' },
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
