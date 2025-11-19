const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: process.env.FIREBASE_PROJECT_ID,
  storageBucket: `${process.env.FIREBASE_PROJECT_ID}.appspot.com`
});

const db = admin.firestore();
const auth = admin.auth();
const storage = admin.storage();

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