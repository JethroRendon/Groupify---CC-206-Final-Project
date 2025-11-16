const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: process.env.FIREBASE_PROJECT_ID
});

const db = admin.firestore();
const auth = admin.auth();

// Firestore collections
const collections = {
  USERS: 'users'
};

console.log('✅ Firebase Admin Initialized Successfully');

module.exports = { admin, db, auth, collections };