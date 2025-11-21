// routes/groups.js
const express = require('express');
const { db, admin } = require('../config/firebase');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();
const GROUPS_COLLECTION = 'groups';
const USERS_COLLECTION = 'users';
const NOTIFICATIONS_COLLECTION = 'notifications';

async function createNotification({ userId, type, groupId, message, actorId }) {
  try {
    if (!userId) return;
    const data = {
      userId,
      type,
      groupId: groupId || null,
      taskId: null,
      message: message || '',
      actorId: actorId || null,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await db.collection(NOTIFICATIONS_COLLECTION).add(data);
  } catch (e) {
    console.warn('createNotification(groups) failed', e.message);
  }
}

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

    // Notify creator that group was created
    try {
      await createNotification({
        userId: req.user.uid,
        type: 'group_created',
        groupId: groupRef.id,
        message: `Group "${name}" created successfully`,
        actorId: req.user.uid
      });
    } catch (e) { console.warn('group_created notification failed', e.message); }

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
// GET GROUP MEMBERS (expanded user details)
// ============================================
router.get('/:groupId/members', authenticateToken, async (req, res) => {
  try {
    const { groupId } = req.params;
    const groupDoc = await db.collection(GROUPS_COLLECTION).doc(groupId).get();

    if (!groupDoc.exists) {
      return res.status(404).json({ success: false, error: 'Group not found' });
    }

    const groupData = groupDoc.data();
    if (!groupData.members || !Array.isArray(groupData.members)) {
      return res.status(200).json({ success: true, members: [] });
    }

    // Only members can view member list
    if (!groupData.members.includes(req.user.uid)) {
      return res.status(403).json({ success: false, error: 'Access denied. You are not a member of this group' });
    }

    const memberIds = groupData.members.slice(0, 200); // safety limit
    const memberDocs = await Promise.all(memberIds.map(async (uid) => {
      try {
        const userSnap = await db.collection(USERS_COLLECTION).doc(uid).get();
        if (!userSnap.exists) {
          return { uid, fullName: 'Unknown', email: '', missing: true };
        }
        const userData = userSnap.data() || {};
        return {
          uid,
          fullName: (userData.fullName || '').toString().trim() || 'Unnamed',
          email: (userData.email || '').toString().trim(),
        };
      } catch (e) {
        return { uid, fullName: 'Error', email: '', error: e.message };
      }
    }));

    res.status(200).json({ success: true, count: memberDocs.length, members: memberDocs });
  } catch (error) {
    console.error('Get group members error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
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

    // In-app notification for successful join
    try {
      await createNotification({
        userId: req.user.uid,
        type: 'group_joined',
        groupId: groupDoc.id,
        message: `You joined group "${groupData.name || 'Unnamed'}"`,
        actorId: req.user.uid,
      });
    } catch {}

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
    await db.collection(GROUPS_COLLECTION).doc(groupId).update({ isActive: false });

    // Remove group from all members' groupIds (skip missing docs to avoid errors)
    if (Array.isArray(groupData.members) && groupData.members.length) {
      const batch = db.batch();
      let queued = 0;
      for (const memberId of groupData.members) {
        try {
          const userRef = db.collection(USERS_COLLECTION).doc(memberId);
          const userSnap = await userRef.get();
          if (!userSnap.exists) {
            continue; // skip if user doc missing
          }
          batch.update(userRef, {
            groupIds: admin.firestore.FieldValue.arrayRemove(groupId)
          });
          queued++;
        } catch (e) {
          console.warn(`Skip updating user ${memberId} during group delete: ${e.message}`);
        }
      }
      if (queued > 0) {
        await batch.commit();
      }
    }

    res.status(200).json({
      success: true,
      message: 'Group deleted successfully'
    });

  } catch (error) {
    console.error('Delete group error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error',
      debugError: error?.message || String(error)
    });
  }
});

// ============================================
// LEAVE GROUP (non-creator)
// ============================================
router.post('/:groupId/leave', authenticateToken, async (req, res) => {
  try {
    const { groupId } = req.params;
    const groupRef = db.collection(GROUPS_COLLECTION).doc(groupId);
    const groupSnap = await groupRef.get();
    if (!groupSnap.exists) {
      return res.status(404).json({ success: false, error: 'Group not found' });
    }
    const groupData = groupSnap.data();
    if (!Array.isArray(groupData.members) || !groupData.members.includes(req.user.uid)) {
      return res.status(400).json({ success: false, error: 'You are not a member of this group' });
    }
    if (groupData.createdBy === req.user.uid) {
      return res.status(400).json({ success: false, error: 'Group creator must delete or transfer ownership before leaving' });
    }

    // Remove user from members array
    const newMembers = groupData.members.filter(m => m !== req.user.uid);
    await groupRef.update({ members: newMembers });

    // Remove groupId from user's groupIds (skip if user doc missing)
    try {
      const userRef = db.collection(USERS_COLLECTION).doc(req.user.uid);
      const userSnap = await userRef.get();
      if (userSnap.exists) {
        await userRef.update({
          groupIds: admin.firestore.FieldValue.arrayRemove(groupId)
        });
      }
    } catch (e) {
      console.warn('Leave group: failed updating user doc', e);
    }

    // If no members left, optionally mark inactive
    if (newMembers.length === 0) {
      await groupRef.update({ isActive: false });
    }

    // Notify the user themselves
    try {
      await createNotification({
        userId: req.user.uid,
        type: 'group_left',
        groupId,
        message: `You left group "${groupData.name || 'Unnamed'}"`,
        actorId: req.user.uid
      });
    } catch (e) { console.warn('group_left notification failed', e.message); }

    // Notify remaining members (excluding leaver) that member left
    try {
      if (Array.isArray(newMembers) && newMembers.length) {
        for (const memberId of newMembers) {
          await createNotification({
            userId: memberId,
            type: 'member_left',
            groupId,
            message: `A member left: ${req.user.uid}`,
            actorId: req.user.uid
          });
        }
      }
    } catch (e) { console.warn('member_left broadcast failed', e.message); }

    return res.status(200).json({ success: true, message: 'Left group successfully' });
  } catch (error) {
    console.error('Leave group error:', error);
    return res.status(500).json({ success: false, error: 'Internal server error', debugError: error?.message || String(error) });
  }
});

module.exports = router;