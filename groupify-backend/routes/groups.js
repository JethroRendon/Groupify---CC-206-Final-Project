// routes/groups.js
const express = require('express');
const { db, admin } = require('../config/firebase');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();
const GROUPS_COLLECTION = 'groups';
const USERS_COLLECTION = 'users';

// Generate unique access code
function generateAccessCode() {
  return Math.random().toString(36).substring(2, 8).toUpperCase();
}

// ============================================
// CREATE GROUP
// ============================================
router.post('/create', authenticateToken, async (req, res) => {
  try {
    const { name, description, subject } = req.body;

    if (!name || !subject) {
      return res.status(400).json({ 
        success: false,
        error: 'Group name and subject are required' 
      });
    }

    const accessCode = generateAccessCode();
    
    const groupData = {
      name,
      description: description || '',
      subject,
      createdBy: req.user.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      members: [req.user.uid], // Creator is automatically a member
      accessCode,
      isActive: true
    };

    const groupRef = await db.collection(GROUPS_COLLECTION).add(groupData);

    // Add group to user's groupIds
    await db.collection(USERS_COLLECTION).doc(req.user.uid).update({
      groupIds: admin.firestore.FieldValue.arrayUnion(groupRef.id)
    });

    res.status(201).json({
      success: true,
      message: 'Group created successfully',
      group: {
        id: groupRef.id,
        ...groupData,
        createdAt: new Date().toISOString()
      }
    });

  } catch (error) {
    console.error('Create group error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// GET USER'S GROUPS
// ============================================
router.get('/my-groups', authenticateToken, async (req, res) => {
  try {
    const groupsSnapshot = await db.collection(GROUPS_COLLECTION)
      .where('members', 'array-contains', req.user.uid)
      .where('isActive', '==', true)
      .get();

    const groups = [];
    groupsSnapshot.forEach(doc => {
      groups.push({
        id: doc.id,
        ...doc.data()
      });
    });

    res.status(200).json({
      success: true,
      count: groups.length,
      groups
    });

  } catch (error) {
    console.error('Get groups error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// GET GROUP BY ID
// ============================================
router.get('/:groupId', authenticateToken, async (req, res) => {
  try {
    const { groupId } = req.params;
    const groupDoc = await db.collection(GROUPS_COLLECTION).doc(groupId).get();

    if (!groupDoc.exists) {
      return res.status(404).json({ 
        success: false,
        error: 'Group not found' 
      });
    }

    const groupData = groupDoc.data();

    // Check if user is a member
    if (!groupData.members.includes(req.user.uid)) {
      return res.status(403).json({ 
        success: false,
        error: 'Access denied. You are not a member of this group' 
      });
    }

    res.status(200).json({
      success: true,
      group: {
        id: groupDoc.id,
        ...groupData
      }
    });

  } catch (error) {
    console.error('Get group error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// JOIN GROUP (via access code)
// ============================================
// JOIN GROUP (via access code)
router.post('/join', authenticateToken, async (req, res) => {
  try {
    const { accessCode } = req.body;

    if (!accessCode) {
      return res.status(400).json({ 
        success: false,
        error: 'Access code is required' 
      });
    }

    // Find group by access code
    const groupsSnapshot = await db.collection(GROUPS_COLLECTION)
      .where('accessCode', '==', accessCode.toUpperCase())
      .where('isActive', '==', true)
      .limit(1)
      .get();

    if (groupsSnapshot.empty) {
      return res.status(404).json({ 
        success: false,
        error: 'Invalid access code' 
      });
    }

    const groupDoc = groupsSnapshot.docs[0];
    const groupData = groupDoc.data();

    // Check if already a member
    if (groupData.members.includes(req.user.uid)) {
      return res.status(400).json({ 
        success: false,
        error: 'You are already a member of this group' 
      });
    }

    // Add user to group members
    await db.collection(GROUPS_COLLECTION).doc(groupDoc.id).update({
      members: admin.firestore.FieldValue.arrayUnion(req.user.uid)
    });

    // FIXED: Check if user document exists first
    const userRef = db.collection(USERS_COLLECTION).doc(req.user.uid);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      // Create minimal user document if it doesn't exist
      await userRef.set({
        uid: req.user.uid,
        email: req.user.email,
        groupIds: [groupDoc.id],
        createdAt: new Date().toISOString()
      });
    } else {
      // Update existing user document
      await userRef.update({
        groupIds: admin.firestore.FieldValue.arrayUnion(groupDoc.id)
      });
    }

    res.status(200).json({
      success: true,
      message: 'Successfully joined group',
      group: {
        id: groupDoc.id,
        ...groupData
      }
    });

  } catch (error) {
    console.error('Join group error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error: ' + error.message 
    });
  }
});

// ============================================
// UPDATE GROUP
// ============================================
router.put('/:groupId', authenticateToken, async (req, res) => {
  try {
    const { groupId } = req.params;
    const { name, description, subject } = req.body;

    const groupDoc = await db.collection(GROUPS_COLLECTION).doc(groupId).get();

    if (!groupDoc.exists) {
      return res.status(404).json({ 
        success: false,
        error: 'Group not found' 
      });
    }

    const groupData = groupDoc.data();

    // Only creator can update group
    if (groupData.createdBy !== req.user.uid) {
      return res.status(403).json({ 
        success: false,
        error: 'Only group creator can update group details' 
      });
    }

    const updateData = {};
    if (name) updateData.name = name;
    if (description !== undefined) updateData.description = description;
    if (subject) updateData.subject = subject;

    if (Object.keys(updateData).length === 0) {
      return res.status(400).json({ 
        success: false,
        error: 'No fields to update' 
      });
    }

    await db.collection(GROUPS_COLLECTION).doc(groupId).update(updateData);

    res.status(200).json({
      success: true,
      message: 'Group updated successfully'
    });

  } catch (error) {
    console.error('Update group error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// DELETE GROUP
// ============================================
router.delete('/:groupId', authenticateToken, async (req, res) => {
  try {
    const { groupId } = req.params;
    const groupDoc = await db.collection(GROUPS_COLLECTION).doc(groupId).get();

    if (!groupDoc.exists) {
      return res.status(404).json({ 
        success: false,
        error: 'Group not found' 
      });
    }

    const groupData = groupDoc.data();

    // Only creator can delete group
    if (groupData.createdBy !== req.user.uid) {
      return res.status(403).json({ 
        success: false,
        error: 'Only group creator can delete group' 
      });
    }

    // Soft delete (mark as inactive)
    await db.collection(GROUPS_COLLECTION).doc(groupId).update({
      isActive: false
    });

    // Remove group from all members' groupIds
    const batch = db.batch();
    groupData.members.forEach(memberId => {
      const userRef = db.collection(USERS_COLLECTION).doc(memberId);
      batch.update(userRef, {
        groupIds: admin.firestore.FieldValue.arrayRemove(groupId)
      });
    });
    await batch.commit();

    res.status(200).json({
      success: true,
      message: 'Group deleted successfully'
    });

  } catch (error) {
    console.error('Delete group error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

module.exports = router;