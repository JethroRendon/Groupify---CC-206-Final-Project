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