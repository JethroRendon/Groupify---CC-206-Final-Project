import 'package:flutter/material.dart';
import 'services/groups_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _groupsService = GroupsService();
  bool _loadingGroup = true;
  bool _loadingMembers = true;
  Map<String, dynamic>? _group;
  List<dynamic> _members = [];
  String? _error;
  bool _changed = false; // track edits/deletes

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loadingGroup = true; _loadingMembers = true; _error = null; });
    try {
      final groupResp = await _groupsService.getGroupById(widget.groupId);
      setState(() { _group = groupResp['group'] ?? groupResp; _loadingGroup = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load group: $e'; _loadingGroup = false; });
    }
    try {
      final membersResp = await _groupsService.getGroupMembers(widget.groupId);
      setState(() { _members = membersResp; _loadingMembers = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load members: $e'; _loadingMembers = false; });
    }
  }

  bool get _isCreator {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && _group != null && _group!['createdBy'] == uid;
  }

  Future<void> _showEditDialog() async {
    if (_group == null) return;
    final nameController = TextEditingController(text: _group!['name'] ?? '');
    final subjectController = TextEditingController(text: _group!['subject'] ?? '');
    final descController = TextEditingController(text: _group!['description'] ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Subject required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true) {
      try {
        await _groupsService.updateGroup(
          widget.groupId,
          name: nameController.text.trim(),
          subject: subjectController.text.trim(),
          description: descController.text.trim(),
        );
        _changed = true;
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group updated'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _confirmDelete() async {
    if (_group == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text('This will remove the group for all members. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _groupsService.deleteGroup(widget.groupId);
        _changed = true;
        if (mounted) {
          Navigator.pop(context, true); // return to list with refresh flag
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          if (_isCreator) PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _showEditDialog();
              if (value == 'delete') _confirmDelete();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')), 
              const PopupMenuItem(value: 'delete', child: Text('Delete Group')), 
            ],
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _changed),
        ),
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_loadingGroup) const LinearProgressIndicator(),
                    if (_group != null) ...[
                      Text(_group!['name'] ?? widget.groupName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Subject: ${_group!['subject'] ?? 'N/A'}'),
                      if ((_group!['description'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(_group!['description']),
                      ],
                      const SizedBox(height: 12),
                      Text('Access Code: ${_group!['accessCode'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w500)),
                      const Divider(height: 32),
                    ],
                    Row(
                      children: [
                        const Text('Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        if (_loadingMembers) const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!_loadingMembers && _members.isEmpty)
                      const Text('No members found.'),
                    if (_members.isNotEmpty)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _members.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final m = _members[i];
                          final name = (m['fullName'] ?? '').toString().trim();
                          final email = (m['email'] ?? '').toString().trim();
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF3B82F6),
                              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text(name.isNotEmpty ? name : 'Unnamed'),
                            subtitle: email.isNotEmpty ? Text(email) : null,
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      if (!_isCreator)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.exit_to_app, color: Colors.red),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Leave Group'),
                                  content: const Text('Are you sure you want to leave this group?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Leave'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                try {
                                  await _groupsService.leaveGroup(widget.groupId);
                                  _changed = true;
                                  if (mounted) {
                                    Navigator.pop(context, true);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left group'), backgroundColor: Colors.green));
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to leave: $e'), backgroundColor: Colors.red));
                                  }
                                }
                              }
                            },
                            label: const Text('Leave Group'),
                          ),
                        ),
                  ],
                ),
              ),
            ),
    );
  }
}
