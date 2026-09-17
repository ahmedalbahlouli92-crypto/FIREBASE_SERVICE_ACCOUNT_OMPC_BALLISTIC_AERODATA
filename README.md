# ompc_ballistic_aerodata

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Web Deployment (Firebase Hosting)

This project is configured to deploy the web target to Google Firebase Hosting.

### Prerequisites

1. Install the Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```
2. Log in to Firebase:
   ```bash
   firebase login
   ```

### Local Build & Deployment

You can build and deploy the web app locally using the configured npm scripts:

- **Build the web app**:
  ```bash
  npm run build:web
  ```
- **Deploy to Firebase Hosting**:
  ```bash
  npm run deploy:web
  ```

### Automated Deployment (GitHub Actions)

A GitHub Actions workflow is configured in `.github/workflows/deploy_web.yml`. It will automatically build and deploy the application to the live channel on Firebase Hosting on every push to the `main` or `master` branches.

To enable this:
1. In the Google Cloud / Firebase Console, create a service account with the **Firebase Hosting Admin** role.
2. Generate and download a JSON key for the service account.
3. In your GitHub Repository, add a secret named `FIREBASE_SERVICE_ACCOUNT_OMPC_BALLISTIC_AERODATA` containing the raw JSON key content.

