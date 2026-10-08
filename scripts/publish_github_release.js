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
const TAG_NAME = 'v1.9.9';
const RELEASE_NAME = 'OMPC Ballistic AeroData v1.9.9 (Multi-Temp EPVAT, Weapon Cascading & UI Suite Update)';
const BODY = `## OMPC Ballistic AeroData v1.9.9

Comprehensive ballistic suite update featuring admin EPVAT component editing, dynamic weapon cascading without AUG fallback, 2-page multi-temperature EPVAT reports with SS109 universal format, powder charge entry, split-screen responsiveness, dynamic terminal effect plates, and date-based sequential REF numbers:

### Key Enhancements & Features:
1. **Admin EPVAT Component Editability**: Administrators can directly edit/type primer supplier, primer lot, propellant supplier, propellant code, and propellant lot.
2. **Dynamic Weapon Cascading**: Caliber -> Weapon Type -> Weapon Model -> Serial Number cascading with empty initial selection (no AUG Steyr default).
3. **Module Switch Automatic Test Reset**: Switching modules immediately sets and displays the first test of that module.
4. **Dashboard Filter Hierarchy & Chart Scoping**: Filters strictly reordered to Shift -> Time Range -> Caliber -> Test Type -> Lot Number with full chart scoping.
5. **EPVAT 2-Page Multi-Temperature Report**: All 3 temperatures (+21°C, +52°C, -54°C) rendered on Page 1; clean page break before Ballistic Analysis calculations, KE, and signatures onto Page 2.
6. **Universal SS109 EPVAT Template**: Standardized NATO SS109 structure applied to all calibers.
7. **12-Hour AM/PM Format**: Formatted across all exported reports, inspection logs, and views.
8. **EPVAT Powder Charge**: Direct entry and validation of Powder Charge in grams.
9. **Inspection Log Time Sorting**: Chronological descending order by user-inserted test time.
10. **Clean Daily Test Lot Display**: Hopper and box clutter stripped to show clean lot number (e.g. 276-26).
11. **Removal of Unregistered Lots**: Clean freeform fallback when no registered lots exist.
12. **Desktop File Attachment Picker**: Windows PowerShell native OpenFileDialog fallback.
13. **EPVAT Sensor Labels**: Renamed to GP6 (1) Chamber and GP6 (2) Port.
14. **Universal Sequential REF Counter**: Daily date-based sequential REF counter across all modules, tests, and components.
15. **Admin Equipment Report Status**: Admins can freely reopen or change status to Under Process / Open.
16. **Dynamic Terminal Effect Plates**: Admin-configurable Plate 1 and Plate 2 Material & Thickness dynamically rendered in forms and reports.
17. **Responsive Consumables & Split-Screen UI**: Auto-collapsing sidebar and wrap for split-screen snapping on PC without layout scattering.
18. **Cross-Platform Deployment**: Published to Firebase Hosting, GitHub repository, and Windows Desktop standalone installer.
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
    { name: 'OMPC_Ballistic_AeroData_v1.9.8.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.9.8.apk' },
    { name: 'OMPC_Ballistic_AeroData_v1.9.7.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.9.7.apk' },
    { name: 'OMPC_Ballistic_AeroData_v1.9.5.apk', path: 'C:\\Users\\user\\Desktop\\OMPC_Ballistic_AeroData_v1.9.5.apk' },
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
