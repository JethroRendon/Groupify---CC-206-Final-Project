// routes/tasks.js
const express = require('express');
const { db, admin } = require('../config/firebase');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// Email integration removed (in-app notifications only)
// ============================================
// Assignment Notification Orchestrator
// ============================================
const ASSIGNMENT_DEDUP_MS = Number(process.env.ASSIGNMENT_DEDUP_MS || 300000); // 5 minutes default
const recentAssignments = new Map(); // key: taskId:assigneeId -> timestamp

function sendAssignmentNotification({
  taskId,
  title,
  description,
  groupId,
  groupName,
  dueDate,
  priority,
  assigneeId,
  assigneeName,
  assignerId,
  assignerName
}) {
  // Non-blocking
  setImmediate(async () => {
    try {
      if (!assigneeId) return;
      const key = `${taskId}:${assigneeId}`;
      const now = Date.now();
      const last = recentAssignments.get(key) || 0;
      if (now - last < ASSIGNMENT_DEDUP_MS) {
        console.log('[Assign][Notify] Suppressed duplicate assignment notification for', key);
        return;
      }
      recentAssignments.set(key, now);
      // Resolve assigner name if missing
      let finalAssignerName = assignerName;
      if (!finalAssignerName && assignerId) {
        try {
          const doc = await db.collection('users').doc(assignerId).get();
          if (doc.exists) {
            const d = doc.data() || {};
            finalAssignerName = d.fullName || d.name || null;
          }
        } catch {}
      }
      const messageParts = [
        `Task: "${title}"`,
        `Assigned By: ${finalAssignerName || 'someone'}`,
        `Priority: ${priority || 'medium'}`,
        `Due: ${dueDate || 'none'}`
      ];
      await createNotification({
        userId: assigneeId,
        type: 'task_assigned',
        taskId,
        groupId,
        message: messageParts.join(' | '),
        actorId: assignerId,
      });
      // Email sending removed
    } catch (e) {
      console.warn('[Assign][Notify] Error:', e.message);
    }
  });
}
// (Email queue code removed entirely; all email functionality deprecated)
const TASKS_COLLECTION = 'tasks';
const GROUPS_COLLECTION = 'groups';
const NOTIFICATIONS_COLLECTION = 'notifications';
const ACTIVITY_LOGS_COLLECTION = 'activityLogs';

async function createNotification({ userId, type, taskId, groupId, message, actorId }) {
  try {
    if (!userId) return;
    if (userId === actorId && type !== 'task_assigned') return; // allow self notification only for assignment
    const data = {
      userId,
      type, // e.g. task_assigned, task_status, task_progress
      taskId: taskId || null,
      groupId: groupId || null,
      message: message || '',
      actorId: actorId || null,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await db.collection(NOTIFICATIONS_COLLECTION).add(data);
  } catch (e) {
    console.warn('createNotification failed', e);
  }
}

async function logActivity({ groupId, userId, action, details, metadata }) {
  try {
    if (!groupId || !userId || !action) return;
    const payload = {
      groupId,
      userId,
      action,
      details: details || '',
      metadata: metadata || {},
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };
    const ref = await db.collection(ACTIVITY_LOGS_COLLECTION).add(payload);
    console.log('[Activity][Write] task route action=', action, 'id=', ref.id, 'groupId=', groupId);
  } catch (e) {
    console.warn('[Tasks][Activity] Failed:', e.message);
  }
}

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
    if (!Array.isArray(groupData.members)) {
      console.error('Group members missing or invalid for group:', groupDoc.id);
      return res.status(500).json({ success: false, error: 'Group members missing or invalid' });
    }

    if (!groupData.members.includes(req.user.uid)) {
      return res.status(403).json({ 
        success: false,
        error: 'You are not a member of this group' 
      });
    }

    // If assignedTo provided, ensure it's a member of the group
    let assignedToName = null;
    let assignedToEmail = null;
    let assignerName = null;
    if (assignedTo) {
      if (!groupData.members.includes(assignedTo)) {
        return res.status(400).json({ success: false, error: 'Assigned user is not a group member' });
      }
      try {
        const userDoc = await db.collection('users').doc(assignedTo).get();
        if (userDoc.exists) {
          const u = userDoc.data() || {};
          console.log('[Assign][Create] userDoc exists for', assignedTo, 'email=', u.email, 'fullName=', u.fullName);
            assignedToName = u.fullName || u.name || null;
          assignedToEmail = u.email || null;
          if (!assignedToEmail) console.warn('[Assign][Create] userDoc missing email for', assignedTo);
        }
        else {
          console.warn('[Assign][Create] userDoc NOT found for', assignedTo);
        }
      } catch (e) {
        console.warn('Lookup assigned user failed:', e);
      }
    }

    // Fetch assigning user name for email content
    try {
      const assignerDoc = await db.collection('users').doc(req.user.uid).get();
      if (assignerDoc.exists) {
        const a = assignerDoc.data() || {};
        assignerName = a.fullName || a.name || null;
      }
    } catch (e) {
      console.warn('Lookup assigner user failed:', e.message);
    }

    const taskData = {
      title,
      description: description || '',
      groupId,
      assignedTo: assignedTo || null,
      assignedToName,
      assignedToEmail,
      assignedBy: req.user.uid,
      assignedByName: assignerName || null,
      status: 'To Do',
      priority: priority || 'medium',
      dueDate: dueDate || null,
      progress: 0,
      startedAt: null,
      completedAt: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    const taskRef = await db.collection(TASKS_COLLECTION).add(taskData);

    // Trigger asynchronous assignment notification
    if (assignedTo) {
      sendAssignmentNotification({
        taskId: taskRef.id,
        title,
        description,
        groupId,
        groupName: groupData.name || groupData.title || 'your group',
        dueDate,
        priority: priority || 'medium',
        assigneeId: assignedTo,
        assigneeEmail: assignedToEmail,
        assigneeName: assignedToName,
        assignerId: req.user.uid,
        assignerName: assignerName
      });
      // Activity: assignment at creation
      logActivity({
        groupId,
        userId: req.user.uid,
        action: 'task_assigned',
        details: `Assigned task "${title}" to ${assignedToName || 'member'}`,
        metadata: { taskId: taskRef.id, assigneeId: assignedTo, assigneeName: assignedToName }
      });
    }

    // Broadcast new task to all other group members
    for (const memberId of groupData.members) {
      if (memberId === req.user.uid || (assignedTo && memberId === assignedTo)) continue;
      await createNotification({
        userId: memberId,
        type: 'task_created',
        taskId: taskRef.id,
        groupId,
        message: `New task "${title}" created in your group`,
        actorId: req.user.uid,
      });
    }

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

    // Activity: task creation (after response to minimize latency)
    setImmediate(() => { logActivity({
        groupId,
        userId: req.user.uid,
        action: 'task_created',
        details: `Created task: ${title}`,
        metadata: { taskId: taskRef.id, title, assignedTo: assignedTo || null }
      }); });

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
    if (!Array.isArray(groupData.members)) {
      console.error('Group members missing or invalid for group:', groupDoc.id);
      return res.status(500).json({ success: false, error: 'Group members missing or invalid' });
    }

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
  const startTs = Date.now();
  const uid = req.user && req.user.uid;
  console.log('[Tasks][My] START uid=', uid, 'query=', JSON.stringify(req.query || {}));
  try {
    const { status } = req.query;
    const statusFilter = status || null;
    console.log('[Tasks][My] Building queries statusFilter=', statusFilter);

    let assignedToQuery = db.collection(TASKS_COLLECTION).where('assignedTo', '==', uid);
    let assignedByQuery = db.collection(TASKS_COLLECTION).where('assignedBy', '==', uid);
    if (statusFilter) {
      assignedToQuery = assignedToQuery.where('status', '==', statusFilter);
      assignedByQuery = assignedByQuery.where('status', '==', statusFilter);
    }

    console.log('[Tasks][My] Fetching snapshots');
    const fetchStart = Date.now();
    const [assignedToSnap, assignedBySnap] = await Promise.all([
      assignedToQuery.get(),
      assignedByQuery.get()
    ]);
    console.log('[Tasks][My] Snapshots fetched ms=', Date.now() - fetchStart, 'assignedToCount=', assignedToSnap.size, 'assignedByCount=', assignedBySnap.size);

    const tasksMap = new Map();
    assignedToSnap.forEach(doc => tasksMap.set(doc.id, { id: doc.id, ...doc.data() }));
    assignedBySnap.forEach(doc => { if (!tasksMap.has(doc.id)) tasksMap.set(doc.id, { id: doc.id, ...doc.data() }); });

    const tasks = Array.from(tasksMap.values());
    tasks.sort((a, b) => {
      const da = a.dueDate ? Date.parse(a.dueDate) : null;
      const db = b.dueDate ? Date.parse(b.dueDate) : null;
      if (da === null && db === null) return 0;
      if (da === null) return 1;
      if (db === null) return -1;
      return da - db;
    });

    console.log('[Tasks][My] RESULT count=', tasks.length, 'totalMs=', Date.now() - startTs);
    return res.status(200).json({ success: true, count: tasks.length, tasks });
  } catch (error) {
    console.error('[Tasks][My] ERROR after', Date.now() - startTs, 'ms:', error && error.message, error);
    const devMsg = (process.env.NODE_ENV !== 'production') ? (error && error.message) : undefined;
    return res.status(200).json({ success: true, count: 0, tasks: [], debugError: devMsg });
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
      return res.status(404).json({ success: false, error: 'Task not found' });
    }
    const taskData = taskDoc.data();
    const groupDoc = await db.collection(GROUPS_COLLECTION).doc(taskData.groupId).get();
    const groupData = groupDoc.data();
    if (!Array.isArray(groupData.members)) {
      console.error('Group members missing or invalid for group:', groupDoc.id);
      return res.status(500).json({ success: false, error: 'Group members missing or invalid' });
    }
    if (!groupData.members.includes(req.user.uid)) {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }
    return res.status(200).json({ success: true, task: { id: taskDoc.id, ...taskData } });
  } catch (error) {
    console.error('Get task error:', error);
    return res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// ============================================
// UPDATE TASK
// ============================================
router.put('/:taskId', authenticateToken, async (req, res) => {
  try {
    const { taskId } = req.params;
    const { title, description, assignedTo, status, dueDate, priority, progress } = req.body;

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
    if (!Array.isArray(groupData.members)) {
      console.error('Group members missing or invalid for group:', groupDoc.id);
      return res.status(500).json({ success: false, error: 'Group members missing or invalid' });
    }

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
    if (assignedTo !== undefined) {
        const originalAssignedTo = taskData.assignedTo || null;
      // ensure new assignee is member of group
      if (assignedTo && !groupData.members.includes(assignedTo)) {
        return res.status(400).json({ success: false, error: 'Assigned user is not a group member' });
      }
      updateData.assignedTo = assignedTo || null;
      if (assignedTo) {
        try {
          const userDoc = await db.collection('users').doc(assignedTo).get();
          if (userDoc.exists) {
            const u = userDoc.data() || {};
              updateData.assignedToName = u.fullName || u.name || null;
            updateData.assignedToEmail = u.email || null;
            console.log('[Assign][Update] userDoc exists for', assignedTo, 'email=', u.email, 'fullName=', u.fullName);
            if (!updateData.assignedToEmail) console.warn('[Assign][Update] userDoc missing email for', assignedTo);
          } else {
            updateData.assignedToName = null;
            updateData.assignedToEmail = null;
            console.warn('[Assign][Update] userDoc NOT found for', assignedTo);
          }
        } catch (e) {
          console.warn('Lookup assigned user failed:', e);
        }
      } else {
        updateData.assignedToName = null;
        updateData.assignedToEmail = null;
      }
      if (assignedTo && assignedTo !== originalAssignedTo) {
        await createNotification({
          userId: assignedTo,
          type: 'task_assigned',
          taskId,
          groupId: taskData.groupId,
          message: `You were assigned to task "${taskData.title}"`,
          actorId: req.user.uid,
        });
        logActivity({
          groupId: taskData.groupId,
          userId: req.user.uid,
          action: 'task_assigned',
          details: `Assigned task "${taskData.title}" to ${updateData.assignedToName || 'member'}`,
          metadata: { taskId, assigneeId: assignedTo, assigneeName: updateData.assignedToName || null }
        });
        // Optionally notify previous assignee
        if (originalAssignedTo && originalAssignedTo !== assignedTo) {
          await createNotification({
            userId: originalAssignedTo,
            type: 'task_unassigned',
            taskId,
            groupId: taskData.groupId,
            message: `You were unassigned from task "${taskData.title}"`,
            actorId: req.user.uid,
          });
          logActivity({
            groupId: taskData.groupId,
            userId: req.user.uid,
            action: 'task_unassigned',
            details: `Unassigned user from task "${taskData.title}"`,
            metadata: { taskId, previousAssigneeId: originalAssignedTo }
          });
        }
          // Broadcast assignment change to other group members
          for (const memberId of groupData.members) {
            if (memberId === req.user.uid || memberId === assignedTo || memberId === originalAssignedTo) continue;
            await createNotification({
              userId: memberId,
              type: 'task_assignment_changed',
              taskId: taskId,
              groupId: taskData.groupId,
              message: `Task "${taskData.title}" assigned to ${updateData.assignedToName || 'a member'}`,
              actorId: req.user.uid,
            });
          }
          // Defer reassignment notification until after DB update
          if (updateData.assignedTo) {
            req._assignmentNotificationPayload = {
              taskId,
              title: taskData.title,
              description: (updateData.description !== undefined ? updateData.description : taskData.description) || 'No description',
              groupId: taskData.groupId,
              groupName: groupData.name || groupData.title || 'your group',
              dueDate: (updateData.dueDate || taskData.dueDate) || null,
              priority: (updateData.priority || taskData.priority) || 'medium',
              assigneeId: updateData.assignedTo,
              assigneeEmail: updateData.assignedToEmail,
              assigneeName: updateData.assignedToName,
              assignerId: req.user.uid,
              assignerName: null
            };
          }
      }
    }

    // Handle progress updates (0-100). Only assignee or creator can update progress
    if (progress !== undefined) {
      const p = Number(progress);
      if (Number.isNaN(p) || p < 0 || p > 100) {
        return res.status(400).json({ success: false, error: 'Progress must be between 0 and 100' });
      }
      if (taskData.assignedTo && req.user.uid !== taskData.assignedTo && req.user.uid !== taskData.assignedBy) {
        return res.status(403).json({ success: false, error: 'Only assignee or creator can update progress' });
      }
      updateData.progress = p;
      if (p > 0 && p < 100) {
        updateData.status = 'In Progress';
        if (!taskData.startedAt) updateData.startedAt = admin.firestore.FieldValue.serverTimestamp();
        logActivity({
          groupId: taskData.groupId,
          userId: req.user.uid,
          action: 'task_progress',
          details: `Progress updated to ${p}% for "${taskData.title}"`,
          metadata: { taskId, progress: p }
        });
      }
      if (p === 100) {
        updateData.status = 'Done';
        updateData.completedAt = admin.firestore.FieldValue.serverTimestamp();
        logActivity({
          groupId: taskData.groupId,
          userId: req.user.uid,
          action: 'task_completed',
          details: `Completed task "${taskData.title}"`,
          metadata: { taskId }
        });
      }
      if (p === 0) {
        updateData.status = 'To Do';
        updateData.startedAt = null;
        updateData.completedAt = null;
        logActivity({
          groupId: taskData.groupId,
          userId: req.user.uid,
          action: 'task_reset',
          details: `Reset progress for task "${taskData.title}"`,
          metadata: { taskId }
        });
      }
      // Notify assignee about progress change if actor is creator, or creator if actor is assignee
      if (taskData.assignedTo) {
        const targetUser = req.user.uid === taskData.assignedTo ? taskData.assignedBy : taskData.assignedTo;
        await createNotification({
          userId: targetUser,
          type: 'task_progress',
          taskId,
          groupId: taskData.groupId,
          message: `Progress updated to ${p}% for task "${taskData.title}"`,
          actorId: req.user.uid,
        });
      }
    }

    if (status) {
      const s = String(status).trim();
      updateData.status = s;
      if (s.toLowerCase() === 'in progress' && !taskData.startedAt) {
        updateData.startedAt = admin.firestore.FieldValue.serverTimestamp();
        if (taskData.progress === 0) updateData.progress = 10; // nudge
        logActivity({ groupId: taskData.groupId, userId: req.user.uid, action: 'task_started', details: `Started task "${taskData.title}"`, metadata: { taskId } });
      }
      if (s.toLowerCase() === 'done') {
        updateData.completedAt = admin.firestore.FieldValue.serverTimestamp();
        updateData.progress = 100;
        logActivity({ groupId: taskData.groupId, userId: req.user.uid, action: 'task_completed', details: `Completed task "${taskData.title}"`, metadata: { taskId } });
      }
      if (s.toLowerCase() === 'to do') {
        updateData.progress = 0;
        updateData.startedAt = null;
        updateData.completedAt = null;
        logActivity({ groupId: taskData.groupId, userId: req.user.uid, action: 'task_reset', details: `Reset task "${taskData.title}" to To Do`, metadata: { taskId } });
      }
      // Notify counterpart user about status change
      if (taskData.assignedTo) {
        const targetUser = req.user.uid === taskData.assignedTo ? taskData.assignedBy : taskData.assignedTo;
        await createNotification({
          userId: targetUser,
          type: 'task_status',
          taskId,
          groupId: taskData.groupId,
          message: `Status changed to ${updateData.status} for task "${taskData.title}"`,
          actorId: req.user.uid,
        });
      }
    }
    if (dueDate !== undefined) updateData.dueDate = dueDate;
    if (priority) updateData.priority = priority;

    await db.collection(TASKS_COLLECTION).doc(taskId).update(updateData);
    if (req._assignmentNotificationPayload) {
      sendAssignmentNotification(req._assignmentNotificationPayload);
    }

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

// (Email test & diagnostic routes removed.)

module.exports = router;