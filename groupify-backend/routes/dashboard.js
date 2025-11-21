// routes/dashboard.js
const express = require('express');
const { db } = require('../config/firebase');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();
const TASKS_COLLECTION = 'tasks';
const GROUPS_COLLECTION = 'groups';

// ============================================
// GET DASHBOARD STATS
// ============================================
router.get('/stats', authenticateToken, async (req, res) => {
  try {
    // Get user's groups
    const groupsSnapshot = await db.collection(GROUPS_COLLECTION)
      .where('members', 'array-contains', req.user.uid)
      .where('isActive', '==', true)
      .get();

    const groupIds = [];
    groupsSnapshot.forEach(doc => {
      groupIds.push(doc.id);
    });

    // Get all tasks for user's groups
    let totalTasks = 0;
    let pendingTasks = 0;
    let inProgressTasks = 0;
    let completedTasks = 0;
    let myTasks = 0;

    if (groupIds.length > 0) {
      // Get tasks for each group
      const tasksPromises = groupIds.map(groupId => 
        db.collection(TASKS_COLLECTION)
          .where('groupId', '==', groupId)
          .get()
      );

      const tasksSnapshots = await Promise.all(tasksPromises);

      tasksSnapshots.forEach(snapshot => {
        snapshot.forEach(doc => {
          const taskData = doc.data();
          totalTasks++;

          if (taskData.status === 'To Do') pendingTasks++;
          if (taskData.status === 'In Progress') inProgressTasks++;
          if (taskData.status === 'Done') completedTasks++;
          if (taskData.assignedTo === req.user.uid) myTasks++;
        });
      });
    }

    res.status(200).json({
      success: true,
      stats: {
        totalGroups: groupIds.length,
        totalTasks,
        pendingTasks,
        inProgressTasks,
        completedTasks,
        myTasks,
        completionRate: totalTasks > 0 
          ? Math.round((completedTasks / totalTasks) * 100) 
          : 0
      }
    });

  } catch (error) {
    console.error('Get dashboard stats error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// GET RECENT ACTIVITIES (for dashboard)
// ============================================
router.get('/recent-activities', authenticateToken, async (req, res) => {
  try {
    const { limit = 10 } = req.query;

    // Get user's groups
    const groupsSnapshot = await db.collection(GROUPS_COLLECTION)
      .where('members', 'array-contains', req.user.uid)
      .where('isActive', '==', true)
      .get();

    const groupIds = [];
    groupsSnapshot.forEach(doc => {
      groupIds.push(doc.id);
    });

    if (groupIds.length === 0) {
      return res.status(200).json({
        success: true,
        count: 0,
        activities: []
      });
    }

    // Get recent activities for user's groups
    const activitiesSnapshot = await db.collection('activityLogs')
      .where('groupId', 'in', groupIds.slice(0, 10)) // Firestore 'in' limit is 10
      .orderBy('timestamp', 'desc')
      .limit(parseInt(limit))
      .get();

    const activities = [];
    activitiesSnapshot.forEach(doc => {
      activities.push({
        id: doc.id,
        ...doc.data()
      });
    });

    res.status(200).json({
      success: true,
      count: activities.length,
      activities
    });

  } catch (error) {
    console.error('Get recent activities error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// GET UPCOMING DEADLINES
// ============================================
router.get('/upcoming-deadlines', authenticateToken, async (req, res) => {
  try {
    const { days = 7 } = req.query;
    
    const now = new Date();
    const futureDate = new Date();
    futureDate.setDate(now.getDate() + parseInt(days));

    const tasksSnapshot = await db.collection(TASKS_COLLECTION)
      .where('assignedTo', '==', req.user.uid)
      .where('status', 'in', ['To Do', 'In Progress'])
      .orderBy('dueDate', 'asc')
      .get();

    const upcomingTasks = [];
    tasksSnapshot.forEach(doc => {
      const taskData = doc.data();
      if (taskData.dueDate) {
        const dueDate = new Date(taskData.dueDate);
        if (dueDate >= now && dueDate <= futureDate) {
          upcomingTasks.push({
            id: doc.id,
            ...taskData
          });
        }
      }
    });

    res.status(200).json({
      success: true,
      count: upcomingTasks.length,
      tasks: upcomingTasks
    });

  } catch (error) {
    console.error('Get upcoming deadlines error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

module.exports = router;
// ============================================
// GET FULL OVERVIEW (user, groups, stats, notifications, activities)
// ============================================
router.get('/overview', authenticateToken, async (req, res) => {
  try {
    const uid = req.user.uid;
    // Fetch user profile
    let userProfile = null;
    try {
      const uDoc = await db.collection('users').doc(uid).get();
      if (uDoc.exists) {
        const u = uDoc.data() || {};
        userProfile = {
          uid,
            fullName: u.fullName || u.name || '',
          email: u.email || '',
          school: u.school || null,
          course: u.course || null,
          yearLevel: u.yearLevel || null,
          section: u.section || null,
          profilePicture: u.profilePicture || null
        };
      }
    } catch (e) {
      console.warn('[Overview] user profile fetch failed:', e.message);
    }

    // Groups membership
    const groupsSnapshot = await db.collection(GROUPS_COLLECTION)
      .where('members', 'array-contains', uid)
      .where('isActive', '==', true)
      .get();
    const groups = [];
    const groupIds = [];
    groupsSnapshot.forEach(doc => { groups.push({ id: doc.id, ...doc.data() }); groupIds.push(doc.id); });

    // Tasks stats (reuse logic from /stats)
    let totalTasks = 0, pendingTasks = 0, inProgressTasks = 0, completedTasks = 0, myTasks = 0;
    if (groupIds.length > 0) {
      const tasksPromises = groupIds.map(gid => db.collection(TASKS_COLLECTION).where('groupId', '==', gid).get());
      const tasksSnapshots = await Promise.all(tasksPromises);
      tasksSnapshots.forEach(snapshot => {
        snapshot.forEach(doc => {
          const t = doc.data();
          totalTasks++;
          if (t.status === 'To Do') pendingTasks++;
          if (t.status === 'In Progress') inProgressTasks++;
          if (t.status === 'Done') completedTasks++;
          if (t.assignedTo === uid) myTasks++;
        });
      });
    }
    const stats = {
      totalGroups: groupIds.length,
      totalTasks,
      pendingTasks,
      inProgressTasks,
      completedTasks,
      myTasks,
      completionRate: totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0
    };

    // Notifications (unread first, limited)
    let notifications = [];
    try {
      const nSnap = await db.collection('notifications').where('userId', '==', uid).get();
      nSnap.forEach(doc => notifications.push({ id: doc.id, ...doc.data() }));
      notifications.sort((a,b)=>{
        const aUnread = a.read !== true; const bUnread = b.read !== true;
        if (aUnread !== bUnread) return aUnread? -1: 1;
        const at = a.createdAt && a.createdAt.toMillis ? a.createdAt.toMillis() : 0;
        const bt = b.createdAt && b.createdAt.toMillis ? b.createdAt.toMillis() : 0;
        return bt - at;
      });
      notifications = notifications.slice(0,50);
    } catch(e){ console.warn('[Overview] notifications failed:', e.message); }

    // Activities aggregated per group (limit per group to reduce load)
    const activities = [];
    const userIds = new Set();
    try {
      const perGroupLimit = 5;
      for (const gid of groupIds) {
        const aSnap = await db.collection('activityLogs').where('groupId','==',gid).limit(perGroupLimit).get();
        aSnap.forEach(doc => {
          const data = doc.data();
          activities.push({ id: doc.id, ...data });
          if (data.userId) userIds.add(data.userId);
          if (data.metadata && data.metadata.assigneeId) userIds.add(data.metadata.assigneeId);
        });
      }
      // Sort newest first by timestamp fields
      activities.sort((a,b)=>{
        const ta = a.timestamp && a.timestamp.seconds ? a.timestamp.seconds * 1000 + (a.timestamp.nanoseconds||0)/1000000 : 0;
        const tb = b.timestamp && b.timestamp.seconds ? b.timestamp.seconds * 1000 + (b.timestamp.nanoseconds||0)/1000000 : 0;
        return tb - ta;
      });
      // Enrich names
      const userMap = {};
      await Promise.all(Array.from(userIds).map(async uid2 => {
        try { const uDoc2 = await db.collection('users').doc(uid2).get(); if (uDoc2.exists) { const d = uDoc2.data()||{}; userMap[uid2] = d.fullName || d.name || d.email || 'Unknown'; } } catch {}
      }));
      activities.forEach(act => {
        act.actorName = userMap[act.userId] || null;
        if (act.metadata && act.metadata.assigneeId) act.assigneeName = userMap[act.metadata.assigneeId] || null;
      });
    } catch (e) { console.warn('[Overview] activities failed:', e.message); }

    res.status(200).json({
      success: true,
      overview: {
        user: userProfile,
        groups,
        stats,
        notifications,
        activities
      }
    });
  } catch (error) {
    console.error('Overview error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});