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
const TAG_NAME = 'v2.0.4';
const RELEASE_NAME = 'OMPC Ballistic AeroData v2.0.4 (EPVAT Formulas & Stats-Only, Component Bullet Accuracy, Primer Supplier Sync)';
const BODY = `## OMPC Ballistic AeroData v2.0.4

Major ballistic intelligence suite upgrade delivering key workflow enhancements, formula chaining, component bullet accuracy, and synchronization:

### Key Enhancements & Features:
1. **Single Temp EPVAT Entry ("Stats Only" Mode)**: Users can directly enter summary statistics without entering individual round measurements when only stats are available.
2. **EPVAT Formula Sample Size \`n\`**: Dynamic variable \`n\` (quantity tested) properly wired from quantity produced across all formulas.
3. **EPVAT Chained Formulas**: Output of earlier custom formulas can be seamlessly referenced by subsequent formulas using alias identifiers (\`formula_1\`, \`f1\`, \`calc_1\`, etc.).
4. **Control Module Primer Sensitivity Rules**: Rules restricted strictly to \`7.62\`, \`5.56\`, and \`9mm\` calibers, with limits on Ball Weight, Max limit of $H̄+5SD$, and Min limit of $H̄-2SD$.
5. **Control Module Evaluation Test Dropdown**: Removed non-test categories (\`GP6 Transducers (EPVAT)\`, \`Barrels\`, \`Weapons\`, \`Sampling Locations\`).
6. **Lot Acceptance Primer Sensitivity Supplier Sync**: Product lot entered as usual; user selects verified Primer Supplier to strictly filter and auto-sync read-only sensitivity metrics from submitted Component Test primer lots.
7. **Lot Acceptance Inspection Log Order**: Most recently created lot is displayed at the top of the list.
8. **Submission Validation**: Form prevents submission if test measurement results are completely empty.
9. **Duplicate Submission Alert**: Warns and prompts user for confirmation when a report with the same lot number and test type has already been submitted.
10. **Primer Caliber Family Matching**: Normalized comma vs dot decimals (e.g. \`5,56\` vs \`5.56\`) so primer lots always match accurately.
11. **Daily Test Day Separator**: Single day separator groups all tests submitted on that date regardless of caliber.
12. **Negative Numbers in Accuracy Auto-Extractor**: Full support for negative values ($-x$, $-y$) including Unicode minus symbols.
13. **Component Test Bullet Accuracy Test**: Dedicated accuracy test for bullet components with calibers (\`.223 55, 69, 77 gr\`, \`.308\`, and \`9mm CMJ 124 grain\`) and metadata (Bullet Supplier, Powder Charge, Lot of Shipment, Grain Size, Sample Loading Method, Sample Received Date, Sample Location).
14. **Supabase Schema Updates**: Integrated \`bullet_supplier\`, \`bullet_grain_size\`, \`sample_loading_method\`, \`sample_received_date\`, and \`component_accuracy_test\` schema into Supabase.
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
    { name: 'OMPC_Ballistic_AeroData_v2.0.3.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v2.0.3.apk' },
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
