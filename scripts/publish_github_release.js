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
const TAG_NAME = 'v1.9.5';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.9.5 (Comprehensive Quality & Inspection Suite Update)';
const BODY = `## OMPC Ballistic AeroData v1.9.5

Comprehensive quality inspection update featuring standardized reports, enhanced component testing, natural lot sequencing, and streamlined retesting workflows:

### Key Enhancements & Features:
1. **Inspector Name on Reports**: Prioritizes operators from inspection logs over generic logged-in usernames on all individual and batch test reports.
2. **Lot Acceptance Certificate Cover**: Certificate cover correctly displays generator, while all individual sub-test sheets show their respective inspectors.
3. **Single Page Fitting**: Individual test reports strictly fit within 1 A4 page with optimized print layout.
4. **Unperformed Tests in Lot Certificate**: Omit unperformed test rows from certificate and alert user in UI before generating.
5. **EPVAT Title & Formulas**: Renamed to EPVAT BALLISTIC ANALYSIS, removed Formula Expression column, and displayed evaluated calculation values with units.
6. **Component Module Calibers**: Strictly restricted component calibers to 5.56, 7.62, and 9mm.
7. **Supabase Component Table**: Created and seeded public.component_tests catalog table with RLS policies.
8. **SPC Chart Lot Sequence**: Sorted SPC Matrix chart X-axis strictly by lot number in natural numerical sequence.
9. **Equipment Report Opening & Status Lock**: Added individual issue report viewer and locked resolved/calibrated/closed issues.
10. **Executive Report Table Export**: Added dedicated pure tabular HTML export for executive quality metrics.
11. **Component Test Signatures**: Added selectable technician signature, displaying 3 signatures (or 2 if inspector is technician).
12. **Inspection Log Sorting**: Added filter dropdown to sort logs by Date of Inspection, Lot / Hopper, Test Name, or Caliber.
13. **Waterproof Sealant Notes**: Auto-note 'need for sealant' on failures/retests, and 'sealant applied' on PC110 retest pass.
14. **Primer Retest Action Taken**: Added Action Taken dropdown and enforced New Insertion Depth entry when changing insertion depth.
15. **Reference Number Resequencing**: Resequenced non-deleted records cleanly starting from REF:01.
16. **Standardized Deletion Alerts**: Standardized deletion confirmation messages across history and equipment logs.
17. **Cross-Platform Release**: Full deployment across Web (Firebase Hosting), Windows Desktop Setup & Portable, and Android APK.
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
    { name: 'OMPC_Ballistic_AeroData_v1.9.5.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.9.5.apk' },
    { name: 'OMPC_Ballistic_AeroData_v1.9.4.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.9.4.apk' },
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
