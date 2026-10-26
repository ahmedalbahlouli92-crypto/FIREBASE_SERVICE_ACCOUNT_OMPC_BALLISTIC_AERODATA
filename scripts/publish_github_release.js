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
const TAG_NAME = 'v2.0.8';
const RELEASE_NAME = 'OMPC Ballistic AeroData v2.0.8 (Clean Remarks, Caliber Volume Totals, Executive Volume Overview, 1-Page Certificate, OOC Removal, Annual Lot Isolation & Benchmark Comparison)';
const BODY = `## OMPC Ballistic AeroData v2.0.8

Enterprise ballistic quality suite update introducing clean remarks formatting, total caliber volume exports without lot/hopper clutter, executive module volume analytics across all three modules, 1-page final lot acceptance certificates, SPC chart cleanup (removing OOC labels), annual lot production year isolation, and side-by-side lot/hopper performance benchmarking:

### Key Enhancements & Features:
1. **Inspection Log Clean Remarks & Reference Number Removal**:
   - Remarks column remains completely blank/empty unless user explicitly enters custom observations.
   - Stripped all automated reference tokens, tags, and numbers from export reports.
2. **Tested Caliber Volume Total Export (No Hopper/Lot Rows)**:
   - Export Caliber Volume standalone reports (CSV & Print/PDF) now aggregate totals strictly per caliber specification with volume share percentages, removing individual hopper and lot sub-rows.
3. **Executive Report Caliber & Component Volume Overview**:
   - Integrated full caliber and component volume breakdown across all 3 modules (Lot Acceptance, Daily Test, Component Test).
   - Added prominent in-dashboard breakdown card and dedicated "Export Caliber Volume Alone" action button in the Executive Reports tab.
4. **Final Lot Acceptance Certificate One-Page Fitting**:
   - Calibrated typography, spacing, and table cell heights to ensure generated Word documents fit comfortably and legibly on a single overall page without being microscopic.
5. **Component Test Caliber & Nomenclature Alignment**:
   - Primer Sensitivity volumes are categorized by primed cases (\`5.56 primed cases\`, \`7.62 primed cases\`, \`9mm primed cases\`).
   - Bullet component tests are categorized by projectile calibre (\`.223 bullet\`, \`.308 bullet\`, \`9mm bullet\`).
6. **SPC Chart Simplification (Removal of OOC)**:
   - Removed all Out of Control (OOC) badges, counters, and highlights from SPC charts across in-app charts and exported vector reports, maintaining UCL, Centerline (CL), and LCL control limits.
7. **Lot Acceptance Dashboard Production Year Isolation**:
   - Production year is automatically extracted from lot numbers (e.g. \`001 OMPC/26\` -> Year 26, \`001 OMPC/25\` -> Year 25).
   - Lot Acceptance dashboard strictly isolates and displays records from a single production year at a time via a dedicated Year Selector dropdown.
8. **Side-by-Side Lot & Hopper Benchmark Comparison**:
   - Added multi-selection comparison matrix dialog allowing users to pick two or more lots or hoppers to directly compare test metrics, defect counts, compliance status, and export comparison reports (CSV & Print/PDF).
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
    { name: 'OMPC_Ballistic_AeroData_v2.0.8.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v2.0.8.apk' },
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
