const fs = require('fs');
const https = require('https');
const crypto = require('crypto');
const path = require('path');
const zlib = require('zlib');

function base64url(str) {
  return Buffer.from(str)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

async function getAccessToken() {
  const key = JSON.parse(fs.readFileSync('firebase-key.json', 'utf8'));
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claimSet = {
    iss: key.client_email,
    scope: 'https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/firebase',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now
  };

  const encodedHeader = base64url(JSON.stringify(header));
  const encodedClaimSet = base64url(JSON.stringify(claimSet));
  const signInput = `${encodedHeader}.${encodedClaimSet}`;

  const signer = crypto.createSign('RSA-SHA256');
  signer.update(signInput);
  const signature = signer.sign(key.private_key, 'base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

  const jwt = `${signInput}.${signature}`;
  const postData = `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`;

  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'oauth2.googleapis.com',
      path: '/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(postData)
      }
    }, res => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        const parsed = JSON.parse(body);
        if (parsed.access_token) {
          resolve(parsed.access_token);
        } else {
          reject(new Error(body));
        }
      });
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

function httpsRequest(options, postData) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, res => {
      let body = '';
      res.on('data', c => body += c);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, headers: res.headers, body: JSON.parse(body) });
        } catch (e) {
          resolve({ status: res.statusCode, headers: res.headers, body });
        }
      });
    });
    req.on('error', reject);
    if (postData) {
      if (Buffer.isBuffer(postData) || typeof postData === 'string') {
        req.write(postData);
      } else {
        req.write(JSON.stringify(postData));
      }
    }
    req.end();
  });
}

function getAllFiles(dir, baseDir = dir) {
  let results = [];
  const list = fs.readdirSync(dir);
  for (const file of list) {
    const fullPath = path.join(dir, file);
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) {
      results = results.concat(getAllFiles(fullPath, baseDir));
    } else {
      const relPath = '/' + path.relative(baseDir, fullPath).replace(/\\/g, '/');
      results.push({ fullPath, relPath });
    }
  }
  return results;
}

(async () => {
  try {
    const siteId = 'ompc-ballistic-aerodata';
    const webDir = path.resolve('build', 'web');
    if (!fs.existsSync(webDir)) {
      throw new Error('build/web does not exist. Run "flutter build web --release" first.');
    }

    console.log('Authenticating with Google OAuth2 token...');
    const token = await getAccessToken();

    console.log('Creating new version on Firebase Hosting site...');
    const config = {
      rewrites: [
        { glob: '**', path: '/index.html' }
      ]
    };

    const verRes = await httpsRequest({
      hostname: 'firebasehosting.googleapis.com',
      path: `/v1beta1/sites/${siteId}/versions`,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    }, { config });

    if (verRes.status !== 200 && verRes.status !== 201) {
      throw new Error(`Failed to create version: ${verRes.status} ${JSON.stringify(verRes.body)}`);
    }

    const versionName = verRes.body.name;
    console.log(`Created version: ${versionName}`);

    console.log('Scanning build/web and hashing assets...');
    const files = getAllFiles(webDir);
    const fileHashMap = {};
    const hashToGzMap = {};
    for (const f of files) {
      const buffer = fs.readFileSync(f.fullPath);
      const gzBuffer = zlib.gzipSync(buffer, { level: 9 });
      const hash = crypto.createHash('sha256').update(gzBuffer).digest('hex');
      fileHashMap[f.relPath] = hash;
      hashToGzMap[hash] = gzBuffer;
    }
    console.log(`Total files to deploy: ${files.length}`);

    console.log('Populating files on Firebase Hosting version...');
    const popRes = await httpsRequest({
      hostname: 'firebasehosting.googleapis.com',
      path: `/v1beta1/${versionName}:populateFiles`,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    }, { files: fileHashMap });

    if (popRes.status !== 200) {
      throw new Error(`Failed to populate files: ${popRes.status} ${JSON.stringify(popRes.body)}`);
    }

    const uploadUrl = popRes.body.uploadUrl;
    const requiredHashes = popRes.body.uploadRequiredHashes || [];
    console.log(`Files requiring upload: ${requiredHashes.length} (already cached on CDN: ${files.length - requiredHashes.length})`);

    let uploadedCount = 0;
    for (const hash of requiredHashes) {
      const gzBuffer = hashToGzMap[hash];
      const urlObj = new URL(`${uploadUrl}/${hash}`);
      
      const upRes = await new Promise((resolve, reject) => {
        const req = https.request({
          hostname: urlObj.hostname,
          path: urlObj.pathname + urlObj.search,
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/octet-stream',
            'Content-Length': gzBuffer.length
          }
        }, res => {
          let b = '';
          res.on('data', c => b += c);
          res.on('end', () => resolve({ status: res.statusCode, body: b }));
        });
        req.on('error', reject);
        req.write(gzBuffer);
        req.end();
      });

      if (upRes.status !== 200) {
        throw new Error(`Upload failed for hash ${hash}: ${upRes.status} ${upRes.body}`);
      }
      uploadedCount++;
      if (uploadedCount % 20 === 0 || uploadedCount === requiredHashes.length) {
        console.log(`Uploaded ${uploadedCount}/${requiredHashes.length} files...`);
      }
    }

    console.log('Finalizing version status to FINALIZED...');
    const finRes = await httpsRequest({
      hostname: 'firebasehosting.googleapis.com',
      path: `/v1beta1/${versionName}?update_mask=status`,
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    }, { status: 'FINALIZED' });

    if (finRes.status !== 200) {
      throw new Error(`Failed to finalize version: ${finRes.status} ${JSON.stringify(finRes.body)}`);
    }

    console.log('Releasing version to live site...');
    const relRes = await httpsRequest({
      hostname: 'firebasehosting.googleapis.com',
      path: `/v1beta1/sites/${siteId}/releases?versionName=${encodeURIComponent(versionName)}`,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    if (relRes.status !== 200 && relRes.status !== 201) {
      throw new Error(`Failed to release version: ${relRes.status} ${JSON.stringify(relRes.body)}`);
    }

    console.log('====================================================');
    console.log('SUCCESS! Firebase Hosting deployment completed!');
    console.log('Live URL: https://ompc-ballistic-aerodata.web.app');
    console.log('====================================================');
  } catch (err) {
    console.error('Firebase deploy failed:', err.message);
    process.exit(1);
  }
})();
