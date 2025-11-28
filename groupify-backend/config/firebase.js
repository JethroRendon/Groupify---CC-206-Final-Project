const admin = require('firebase-admin');

// Use environment variable for service account in production, file in development
let serviceAccount;
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} else {
  serviceAccount = require('../serviceAccountKey.json');
}

const projectId = process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id;
const configuredBucket = process.env.FIREBASE_STORAGE_BUCKET || `${projectId}.appspot.com`;

try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId,
    storageBucket: configuredBucket
  });
  console.log('[Firebase] Initialized admin SDK');
  console.log('[Firebase] Project ID:', projectId);
  console.log('[Firebase] Storage Bucket (configured):', configuredBucket);
} catch (initErr) {
  console.error('[Firebase] Initialization failed:', initErr.message);
  throw initErr;
}

const db = admin.firestore();
const auth = admin.auth();
const storage = admin.storage();

// Probe bucket (will not create it; just verifies access)
try {
  const bucket = storage.bucket();
  console.log('[Firebase][Storage] Using bucket name:', bucket.name);
  // List first file (lightweight) to verify existence; errors will surface if bucket missing
  bucket.getFiles({ maxResults: 1 }, (err) => {
    if (err) {
      console.warn('[Firebase][Storage] Bucket access check warning:', err.message);
      if (/Not Found/i.test(err.message) || /does not exist/i.test(err.message)) {
        console.warn('[Firebase][Storage] The specified bucket may not exist. Create it in Firebase Console or Google Cloud Storage: ', configuredBucket);
      }
    } else {
      console.log('[Firebase][Storage] Bucket access verified.');
    }
  });
} catch (bucketErr) {
  console.warn('[Firebase][Storage] Bucket probe failed:', bucketErr.message);
}

// Firestore collections
const collections = {
  USERS: 'users',
  GROUPS: 'groups',
  TASKS: 'tasks',
  FILES: 'files',
  NOTIFICATIONS: 'notifications',
  ACTIVITY_LOGS: 'activityLogs'
};

console.log('✅ Firebase Admin Initialized Successfully');

module.exports = { admin, db, auth, storage, collections };