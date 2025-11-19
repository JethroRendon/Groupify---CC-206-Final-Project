// routes/tasks.js
const express = require('express');
const { db, admin } = require('../config/firebase');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();
const TASKS_COLLECTION = 'tasks';
const GROUPS_COLLECTION = 'groups';

// ============================================
// CREATE TASK
// ============================================
router.post('/create', authenticateToken, async (req, res) => {
  try {
    const { title, description, groupId, assignedTo, dueDate, priority } = req.body;

    if (!title || !groupId) {
      return res.status(400).json({ 
        success: false,
        error: 'Title and group ID are required' 
      });
    }

    // Verify user is member of group
    const groupDoc = await db.collection(GROUPS_COLLECTION).doc(groupId).get();
    if (!groupDoc.exists) {
      return res.status(404).json({ 
        success: false,
        error: 'Group not found' 
      });
    }

    const groupData = groupDoc.data();
    if (!groupData.members.includes(req.user.uid)) {
      return res.status(403).json({ 
        success: false,
        error: 'You are not a member of this group' 
      });
    }

    const taskData = {
      title,
      description: description || '',
      groupId,
      assignedTo: assignedTo || null,
      assignedBy: req.user.uid,
      status: 'To Do',
      priority: priority || 'medium',
      dueDate: dueDate || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    const taskRef = await db.collection(TASKS_COLLECTION).add(taskData);

    res.status(201).json({
      success: true,
      message: 'Task created successfully',
      task: {
        id: taskRef.id,
        ...taskData,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      }
    });

  } catch (error) {
    console.error('Create task error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// GET TASKS BY GROUP
// ============================================
router.get('/group/:groupId', authenticateToken, async (req, res) => {
  try {
    const { groupId } = req.params;
    const { status } = req.query; // Optional filter by status

    // Verify user is member of group
    const groupDoc = await db.collection(GROUPS_COLLECTION).doc(groupId).get();
    if (!groupDoc.exists) {
      return res.status(404).json({ 
        success: false,
        error: 'Group not found' 
      });
    }

    const groupData = groupDoc.data();
    if (!groupData.members.includes(req.user.uid)) {
      return res.status(403).json({ 
        success: false,
        error: 'Access denied' 
      });
    }

    let query = db.collection(TASKS_COLLECTION).where('groupId', '==', groupId);
    
    if (status) {
      query = query.where('status', '==', status);
    }

    const tasksSnapshot = await query.orderBy('createdAt', 'desc').get();

    const tasks = [];
    tasksSnapshot.forEach(doc => {
      tasks.push({
        id: doc.id,
        ...doc.data()
      });
    });

    res.status(200).json({
      success: true,
      count: tasks.length,
      tasks
    });

  } catch (error) {
    console.error('Get tasks error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// GET MY TASKS (assigned to current user)
// ============================================
router.get('/my-tasks', authenticateToken, async (req, res) => {
  try {
    const { status } = req.query;

    let query = db.collection(TASKS_COLLECTION)
      .where('assignedTo', '==', req.user.uid);
    
    if (status) {
      query = query.where('status', '==', status);
    }

    const tasksSnapshot = await query.orderBy('dueDate', 'asc').get();

    const tasks = [];
    tasksSnapshot.forEach(doc => {
      tasks.push({
        id: doc.id,
        ...doc.data()
      });
    });

    res.status(200).json({
      success: true,
      count: tasks.length,
      tasks
    });

  } catch (error) {
    console.error('Get my tasks error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// GET TASK BY ID
// ============================================
router.get('/:taskId', authenticateToken, async (req, res) => {
  try {
    const { taskId } = req.params;
    const taskDoc = await db.collection(TASKS_COLLECTION).doc(taskId).get();

    if (!taskDoc.exists) {
      return res.status(404).json({ 
        success: false,
        error: 'Task not found' 
      });
    }

    const taskData = taskDoc.data();

    // Verify user is member of task's group
    const groupDoc = await db.collection(GROUPS_COLLECTION).doc(taskData.groupId).get();
    const groupData = groupDoc.data();
    
    if (!groupData.members.includes(req.user.uid)) {
      return res.status(403).json({ 
        success: false,
        error: 'Access denied' 
      });
    }

    res.status(200).json({
      success: true,
      task: {
        id: taskDoc.id,
        ...taskData
      }
    });

  } catch (error) {
    console.error('Get task error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// UPDATE TASK
// ============================================
router.put('/:taskId', authenticateToken, async (req, res) => {
  try {
    const { taskId } = req.params;
    const { title, description, assignedTo, status, dueDate, priority } = req.body;

    const taskDoc = await db.collection(TASKS_COLLECTION).doc(taskId).get();

    if (!taskDoc.exists) {
      return res.status(404).json({ 
        success: false,
        error: 'Task not found' 
      });
    }

    const taskData = taskDoc.data();

    // Verify user is member of task's group
    const groupDoc = await db.collection(GROUPS_COLLECTION).doc(taskData.groupId).get();
    const groupData = groupDoc.data();
    
    if (!groupData.members.includes(req.user.uid)) {
      return res.status(403).json({ 
        success: false,
        error: 'Access denied' 
      });
    }

    const updateData = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    if (title) updateData.title = title;
    if (description !== undefined) updateData.description = description;
    if (assignedTo !== undefined) updateData.assignedTo = assignedTo;
    if (status) updateData.status = status;
    if (dueDate !== undefined) updateData.dueDate = dueDate;
    if (priority) updateData.priority = priority;

    await db.collection(TASKS_COLLECTION).doc(taskId).update(updateData);

    res.status(200).json({
      success: true,
      message: 'Task updated successfully'
    });

  } catch (error) {
    console.error('Update task error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// DELETE TASK
// ============================================
router.delete('/:taskId', authenticateToken, async (req, res) => {
  try {
    const { taskId } = req.params;
    const taskDoc = await db.collection(TASKS_COLLECTION).doc(taskId).get();

    if (!taskDoc.exists) {
      return res.status(404).json({ 
        success: false,
        error: 'Task not found' 
      });
    }

    const taskData = taskDoc.data();

    // Only creator can delete task
    if (taskData.assignedBy !== req.user.uid) {
      return res.status(403).json({ 
        success: false,
        error: 'Only task creator can delete task' 
      });
    }

    await db.collection(TASKS_COLLECTION).doc(taskId).delete();

    res.status(200).json({
      success: true,
      message: 'Task deleted successfully'
    });

  } catch (error) {
    console.error('Delete task error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

module.exports = router;