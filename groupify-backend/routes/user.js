const express = require('express');
const { db, collections } = require('../config/firebase');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// ============================================
// GET USER PROFILE
// ============================================
router.get('/profile', authenticateToken, async (req, res) => {
  try {
    const userDoc = await db.collection(collections.USERS).doc(req.user.uid).get();
    
    if (!userDoc.exists) {
      return res.status(404).json({ 
        success: false,
        error: 'User not found' 
      });
    }

    const userData = userDoc.data();

    res.status(200).json({
      success: true,
      user: {
        uid: userData.uid,
        fullName: userData.fullName,
        email: userData.email,
        school: userData.school,
        course: userData.course,
        yearLevel: userData.yearLevel,
        section: userData.section,
        hasSeenOnboarding: userData.hasSeenOnboarding,
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