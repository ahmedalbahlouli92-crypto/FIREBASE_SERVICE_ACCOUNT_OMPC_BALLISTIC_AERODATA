const { GoogleAuth } = require('google-auth-library');
const { execSync } = require('child_process');
const path = require('path');

async function deploy() {
  console.log('Authenticating with Google Cloud / Firebase...');
  const keyPath = path.join(__dirname, '..', 'firebase-key.json');
  const auth = new GoogleAuth({
    keyFile: keyPath,
    scopes: [
      'https://www.googleapis.com/auth/cloud-platform',
      'https://www.googleapis.com/auth/firebase'
    ]
  });

  const client = await auth.getClient();
  const { token } = await client.getAccessToken();

  console.log('Deploying build/web to Firebase Hosting live channel...');
  const output = execSync('npx.cmd -y firebase-tools deploy --only hosting --token ' + token, {
    cwd: path.join(__dirname, '..'),
    encoding: 'utf8',
    stdio: 'inherit'
  });
}

deploy().catch(err => {
  console.error('Firebase deployment failed:', err);
  process.exit(1);
});
