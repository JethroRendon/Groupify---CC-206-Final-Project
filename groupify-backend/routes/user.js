const express = require('express');
const multer = require('multer');
const { db, collections, admin } = require('../config/firebase');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// Configure multer for memory storage
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit for profile pictures
  },
  fileFilter: (req, file, cb) => {
    // Only allow image files
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'));
    }
  },
});

// ============================================
// GET USER PROFILE
// ============================================
router.get('/profile', authenticateToken, async (req, res) => {
  console.log('GET /api/user/profile called for uid:', req.user && req.user.uid);
  try {
    // First attempt: document keyed by auth UID
    let userDoc = await db.collection(collections.USERS).doc(req.user.uid).get();

    // Fallback: if no doc found, try querying by email (useful if user documents were created with different IDs)
    if (!userDoc.exists) {
      console.log('User doc not found by UID, attempting fallback lookup by email:', req.user && req.user.email);
      if (req.user && req.user.email) {
        const q = await db.collection(collections.USERS).where('email', '==', req.user.email).limit(1).get();
        if (!q.empty) {
          userDoc = q.docs[0];
          console.log('Fallback lookup succeeded — found user doc id:', userDoc.id);
        }
      }
    }

    if (!userDoc.exists) {
      return res.status(404).json({ 
        success: false,
        error: 'User not found' 
      });
    }

    const userData = userDoc.data();

    // Sanitize string fields to avoid embedded newlines or excessive whitespace
    const sanitize = (v) => (typeof v === 'string' ? v.replace(/\s+/g, ' ').trim() : v);

    res.status(200).json({
      success: true,
      user: {
        uid: userData.uid,
        fullName: sanitize(userData.fullName) || '',
        email: sanitize(userData.email) || '',
        school: sanitize(userData.school) || '',
        course: sanitize(userData.course) || '',
        yearLevel: sanitize(userData.yearLevel) || '',
        section: sanitize(userData.section) || '',
        profilePicture: userData.profilePicture || null,
        hasSeenOnboarding: !!userData.hasSeenOnboarding,
        createdAt: userData.createdAt,
        lastLogin: userData.lastLogin
      }
    });

  } catch (error) {
    console.error('Profile error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// UPDATE USER PROFILE
// ============================================
router.put('/profile', authenticateToken, async (req, res) => {
  try {
    const { fullName, school, course, yearLevel, section } = req.body;
    
    const updateData = {};
    if (fullName) updateData.fullName = fullName;
    if (school) updateData.school = school;
    if (course) updateData.course = course;
    if (yearLevel) updateData.yearLevel = yearLevel;
    if (section) updateData.section = section;

    if (Object.keys(updateData).length === 0) {
      return res.status(400).json({ 
        success: false,
        error: 'No fields to update' 
      });
    }

    await db.collection(collections.USERS).doc(req.user.uid).update(updateData);

    // Get updated user data
    const userDoc = await db.collection(collections.USERS).doc(req.user.uid).get();
    const userData = userDoc.data();

    res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      user: {
        uid: userData.uid,
        fullName: userData.fullName,
        email: userData.email,
        school: userData.school,
        course: userData.course,
        yearLevel: userData.yearLevel,
        section: userData.section
      }
    });

  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// UPLOAD PROFILE PICTURE
// ============================================
router.post('/profile-picture', authenticateToken, upload.single('profilePicture'), async (req, res) => {
  console.log('[User][ProfilePicture] Upload attempt for uid:', req.user && req.user.uid);
  try {
    const file = req.file;

    if (!file) {
      return res.status(400).json({ success: false, error: 'No file uploaded' });
    }

    // Initialize Firebase Storage bucket
    const bucket = admin.storage().bucket();

    const timestamp = Date.now();
    const filename = `users/${req.user.uid}/profile_${timestamp}.${file.mimetype.split('/')[1]}`;
    const fileUpload = bucket.file(filename);

    // Upload file
    try {
      await fileUpload.save(file.buffer, {
        contentType: file.mimetype,
        resumable: false
      });
    } catch (saveErr) {
      console.error('[User][ProfilePicture] Upload failed:', saveErr.message);
      return res.status(500).json({ success: false, error: 'File upload failed' });
    }

    // Generate signed URL (valid for 7 days)
    let signedUrl = null;
    try {
      [signedUrl] = await fileUpload.getSignedUrl({ 
        action: 'read', 
        expires: Date.now() + 7 * 24 * 3600 * 1000 // 7 days
      });
    } catch (signErr) {
      console.warn('[User][ProfilePicture] Signed URL generation failed:', signErr.message);
    }

    // Update user document with profile picture URL
    await db.collection(collections.USERS).doc(req.user.uid).update({
      profilePicture: signedUrl,
      profilePicturePath: filename,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('[User][ProfilePicture] Successfully uploaded and saved URL');

    res.status(200).json({
      success: true,
      message: 'Profile picture uploaded successfully',
      profilePicture: signedUrl
    });

  } catch (error) {
    console.error('[User][ProfilePicture] Error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// GET ALL USERS (Admin/Debug only)
// ============================================
router.get('/all', authenticateToken, async (req, res) => {
  try {
    const usersSnapshot = await db.collection(collections.USERS).get();
    const users = [];

    usersSnapshot.forEach(doc => {
      users.push({
        uid: doc.id,
        ...doc.data()
      });
    });

    res.status(200).json({
      success: true,
      count: users.length,
      users
    });

  } catch (error) {
    console.error('Get all users error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

module.exports = router;