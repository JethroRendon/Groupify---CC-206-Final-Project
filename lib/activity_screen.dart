import 'package:flutter/material.dart';
import 'services/activities_service.dart';
import 'services/groups_service.dart';
import 'file_screen.dart';
import 'task_screen.dart';
import 'groups_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final ActivitiesService _activitiesService = ActivitiesService();
  final GroupsService _groupsService = GroupsService();
  bool _loading = true;
  List<dynamic> _activities = [];
  List<String> _groupIds = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final groups = await _groupsService.getMyGroups();
      _groupIds = groups.map((g) => g['id'].toString()).toList();
      final acts = await _activitiesService.getActivitiesForGroups(_groupIds, perGroupLimit: 50);
      if (mounted) setState(() { _activities = acts; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearAllActivities() async {
    if (_groupIds.isEmpty) return;
    setState(() => _loading = true);
    try {
      await _activitiesService.clearActivitiesForGroups(_groupIds);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All activities cleared')));
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Activity', style: TextStyle(fontFamily:'Outfit')),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Clear All',
            icon: const Icon(Icons.delete_outline),
            onPressed: _activities.isEmpty ? null : _confirmClear,
          )
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _loadAll,
        child: _activities.isEmpty ? const Center(child: Text('No activity yet', style: TextStyle(fontFamily:'Outfit'))) : ListView.builder(
          itemCount: _activities.length,
          itemBuilder: (ctx,i){ final a = _activities[i]; return _buildActivityTile(a); },
        ),
      ),
    );
  }

  void _confirmClear() {
    showDialog(context: context, builder: (c)=> AlertDialog(
      title: const Text('Clear All Activity', style: TextStyle(fontFamily:'Outfit')),
      content: const Text('This will permanently remove all activity logs for your groups.', style: TextStyle(fontFamily:'Outfit')),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { Navigator.pop(c); _clearAllActivities(); }, child: const Text('Clear All'))
      ],
    ));
  }

  Widget _buildActivityTile(dynamic a) {
    if (a is! Map) return const SizedBox.shrink();
    final actor = (a['actorName'] ?? 'Someone').toString();
    final action = (a['action'] ?? '').toString();
    final details = (a['details'] ?? '').toString();
    final when = _formatTime(a['timestamp']);
    return ListTile(
      onTap: () => _navigateActivity(a),
      title: Text(details.isEmpty ? action : details, style: const TextStyle(fontFamily:'Outfit', fontWeight: FontWeight.w600)),
      subtitle: Text('$actor • $when', style: const TextStyle(fontFamily:'Outfit', fontSize:12, color: Color(0xFF64748B))),
      trailing: _actionChip(action),
    );
  }

  void _navigateActivity(Map a) {
    final action = (a['action'] ?? '').toString();
    if (action.startsWith('file_')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FilesScreen()));
    } else if (action.startsWith('task_')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksScreen()));
    } else if (action.startsWith('group_')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupsScreen()));
    }
  }

  Widget _actionChip(String action) {
    Color bg; Color fg = const Color(0xFF0F172A);
    switch(action){
      case 'file_uploaded': bg = const Color(0xFFDBEAFE); break;
      case 'task_created': bg = const Color(0xFFFEF3C7); break;
      case 'task_assigned': bg = const Color(0xFFE0FEDB); break;
      case 'task_unassigned': bg = const Color(0xFFF1F5F9); break;
      case 'task_progress': bg = const Color(0xFFFAE8FF); break;
      case 'task_completed': bg = const Color(0xFFE0FEDB); break;
      default: bg = const Color(0xFFE2E8F0); break;
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal:10, vertical:6), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)), child: Text(action.replaceAll('_',' '), style: TextStyle(fontFamily:'Outfit', fontSize:11, fontWeight: FontWeight.w500, color: fg)));
  }

  String _formatTime(dynamic ts){
    final ms = _tsMillis(ts);
    if (ms == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  int _tsMillis(dynamic ts){
    if (ts == null) return 0;
    try {
      final s = ts['_seconds'] ?? ts['seconds'];
      final ns = ts['_nanoseconds'] ?? ts['nanoseconds'] ?? 0;
      if (s is int) return s * 1000 + (ns is int ? (ns / 1000000).round() : 0);
    } catch(_){ }
    return 0;
  }
}
