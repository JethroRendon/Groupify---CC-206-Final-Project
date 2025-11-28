import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dashboard.dart';
import 'task_screen.dart';
import 'profilescreen.dart';
import 'services/groups_service.dart';
import 'services/files_service.dart';
import 'services/notifications_service.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  int _selectedBottomNavIndex = 2;
  final _groupsService = GroupsService();
  final _filesService = FilesService();
  final NotificationsService _notificationsService = NotificationsService();

  List<dynamic> _recentFiles = [];
  bool _isLoading = false;
  List<dynamic> _notifications = [];
  int _unread = 0;
  Map<String, List<dynamic>> _fileCategories = {};
  String? _selectedCategory; // null means show category grid

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _loadNotifications();
  }

  Future<void> _loadFiles() async {
    if (_isLoading) return; // prevent duplicate loads
    setState(() => _isLoading = true);
    
    try {
      final groups = await _groupsService.getMyGroups();
      final futures = <Future<List<dynamic>>>[];
      for (var group in groups) {
        futures.add(_filesService.getFilesByGroup(group['id'], signed: false).catchError((_) => <dynamic>[]));
      }
      final results = await Future.wait(futures);
      final allFiles = results.expand((r) => r).toList();
      if (!mounted) return;
      setState(() {
        _recentFiles = allFiles;
        _isLoading = false;
        _recomputeCategories();
      });
    } catch (e) {
      print('Error loading files: $e');
      setState(() => _isLoading = false);
    }
  }

  void _recomputeCategories() {
    final Map<String, List<dynamic>> cats = {
      'Documents': [],
      'Images': [],
      'Videos': [],
      'Others': [],
    };
    for (final f in _recentFiles) {
      if (f is! Map) continue;
      final cat = _categoryForFile(f);
      cats[cat]!.add(f);
    }
    _fileCategories = cats;
  }

  String _categoryForFile(Map file) {
    const documents = [
      'pdf','doc','docx','xls','xlsx','ppt','pptx','txt','rtf','odt','csv'
    ];
    const images = [
      'jpg','jpeg','png','gif','bmp','webp','svg','tiff'
    ];
    const videos = [
      'mp4','mkv','avi','mov','wmv','flv','webm'
    ];
    final rawName = (file['fileName'] ?? '').toString();
    // Remove query params if any and extract extension
    final cleanName = rawName.split('?').first;
    final ext = cleanName.contains('.') ? cleanName.split('.').last.toLowerCase() : '';
    if (documents.contains(ext)) return 'Documents';
    if (images.contains(ext)) return 'Images';
    if (videos.contains(ext)) return 'Videos';
    return 'Others';
  }

  Future<void> _deleteFile(Map file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File', style: TextStyle(fontFamily: 'Outfit')),
        content: Text(
          'Are you sure you want to delete "${file['fileName']}"?',
          style: const TextStyle(fontFamily: 'Outfit'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _filesService.deleteFile(file['id']);
        await _loadFiles(); // _loadFiles handles its own loading state
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete file: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _downloadFile(Map file) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparing download...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Fetch signed URL
      final gid = file['groupId'];
      if (gid == null) {
        throw Exception('Group ID not found');
      }

      final refreshed = await _filesService.getFilesByGroup(gid, signed: true);
      final updated = refreshed.firstWhere(
        (f) => f['id'] == file['id'],
        orElse: () => file,
      );
      
      final url = updated['temporaryUrl'];
      if (url == null || url.toString().isEmpty) {
        throw Exception('Download URL not available');
      }

      // Launch the download URL
      final uri = Uri.parse(url.toString());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloading ${file['fileName']}...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Could not launch download');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _previewFile(Map file) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get signed URL
      final gid = file['groupId'];
      if (gid == null) {
        throw Exception('Group ID not found');
      }

      final refreshed = await _filesService.getFilesByGroup(gid, signed: true);
      final updated = refreshed.firstWhere(
        (f) => f['id'] == file['id'],
        orElse: () => file,
      );

      final url = updated['temporaryUrl'];
      if (url == null || url.toString().isEmpty) {
        throw Exception('File URL not available');
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Check if it's a previewable file type
      final fileName = file['fileName']?.toString().toLowerCase() ?? '';
      final isImage = fileName.endsWith('.jpg') || 
                     fileName.endsWith('.jpeg') || 
                     fileName.endsWith('.png') || 
                     fileName.endsWith('.gif') || 
                     fileName.endsWith('.webp');
      
      final isPdf = fileName.endsWith('.pdf');

      if (isImage || isPdf) {
        // Show preview dialog
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  AppBar(
                    title: Text(
                      file['fileName'] ?? 'Preview',
                      style: const TextStyle(fontFamily: 'Outfit'),
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadFile(file);
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: isImage
                        ? InteractiveViewer(
                            panEnabled: true,
                            boundaryMargin: const EdgeInsets.all(20),
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Center(
                              child: Image.network(
                                url.toString(),
                                fit: BoxFit.contain,
                                headers: const {
                                  'Accept': 'image/*',
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          loadingProgress.expectedTotalBytes != null
                                              ? '${(loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! * 100).toStringAsFixed(0)}%'
                                              : 'Loading...',
                                          style: const TextStyle(fontFamily: 'Outfit'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  print('Image load error: $error');
                                  print('Image URL: ${url.toString()}');
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Failed to load image',
                                          style: TextStyle(fontFamily: 'Outfit'),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            final uri = Uri.parse(url.toString());
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                                            }
                                          },
                                          icon: const Icon(Icons.open_in_new),
                                          label: const Text('Open in Browser'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.picture_as_pdf, size: 64, color: Colors.red),
                                const SizedBox(height: 16),
                                const Text(
                                  'PDF Preview',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final uri = Uri.parse(url.toString());
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('Open in Browser'),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        // For other file types, open in external app
        final uri = Uri.parse(url.toString());
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Opening ${file['fileName']}...'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Cannot open this file type');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close any open dialogs
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preview failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      print('[FilesScreen] Getting groups...');
      final groups = await _groupsService.getMyGroups();
      print('[FilesScreen] Found ${groups.length} groups');
      
      if (groups.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please create a group first!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      print('[FilesScreen] Opening file picker...');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) {
        print('[FilesScreen] No file selected');
        return;
      }

      final file = result.files.first;
      print('[FilesScreen] File selected: ${file.name}, size: ${file.size} bytes');
      
      if (file.bytes == null) {
        print('[FilesScreen] ERROR: File bytes are null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to read file. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      print('[FilesScreen] Showing group selection dialog...');
      final selectedGroupId = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Group', style: TextStyle(fontFamily: 'Outfit')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return ListTile(
                  title: Text(group['name'] ?? 'Unnamed Group'),
                  subtitle: Text(group['subject'] ?? ''),
                  onTap: () => Navigator.pop(context, group['id']),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedGroupId == null) {
        print('[FilesScreen] No group selected');
        return;
      }

      print('[FilesScreen] Group selected: $selectedGroupId');
      
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading file...', style: TextStyle(fontFamily: 'Outfit')),
                ],
              ),
            ),
          ),
        );
      }

      try {
        print('[FilesScreen] Starting upload...');
        final response = await _filesService.uploadFile(
          fileBytes: file.bytes!,
          fileName: file.name,
          groupId: selectedGroupId,
        );
        
        print('[FilesScreen] Upload successful: $response');

        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File uploaded successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Reload files
          await _loadFiles();
          await _loadNotifications();
        }
      } catch (e) {
        print('[FilesScreen] Upload error: $e');
        
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('[FilesScreen] Error in _pickFiles: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final list = await _notificationsService.getMyNotifications();
      int unread = 0; for (final n in list) { if (n['read'] != true) unread++; }
      if (mounted) setState(() { _notifications = list; _unread = unread; });
    } catch (e) { print('Files notifications error: $e'); }
  }

  void _showNotifications() async {
    await _loadNotifications();
    if(!mounted) return;
    showDialog(context: context, builder: (c)=> AlertDialog(
      title: const Text('Notifications', style: TextStyle(fontFamily:'Outfit')),
      content: SizedBox(width: double.maxFinite, child: _notifications.isEmpty? const Text('No notifications') : ListView.builder(
        shrinkWrap: true,
        itemCount: _notifications.length,
        itemBuilder: (ctx,i){ final n=_notifications[i]; return ListTile(
          title: Text(n['message']??'', style: const TextStyle(fontFamily:'Outfit')),
          subtitle: Text((n['type']??'').toString(), style: const TextStyle(fontFamily:'Outfit')),
          trailing: n['read']==true? const Icon(Icons.check,color:Colors.green,size:18) : TextButton(onPressed: () async { await _notificationsService.markRead(n['id']); Navigator.pop(context); _loadNotifications(); }, child: const Text('Mark read')),
        ); },
      )),
      actions: [
        if (_notifications.isNotEmpty)
          TextButton(
            onPressed: () async {
              try {
                await _notificationsService.clearAll();
                Navigator.pop(context);
                _loadNotifications();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications cleared'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear notifications: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Close')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Files',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 20,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            children: [
                              Stack(children:[
                                IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: _showNotifications),
                                if(_unread>0) Positioned(right:6, top:6, child: Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), child: Text(_unread.toString(), style: const TextStyle(color: Colors.white, fontSize:10, fontFamily:'Outfit')))),
                              ]),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ProfileScreen(),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: ShapeDecoration(
                                    color: const Color(0xFFe2E8F0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.person, color: Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Upload Files Area
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 21),
                      child: GestureDetector(
                        onTap: _pickFiles,
                        child: Container(
                          width: double.infinity,
                          height: 177,
                          decoration: ShapeDecoration(
                            color: const Color(0xFFF8FAFC),
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(
                                width: 1,
                                color: Color(0xFFD1D5DB),
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.upload_file,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 11),
                              const Text(
                                'Upload Files',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 18,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap to select files',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 16,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Categories header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 19),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedCategory == null ? 'File Categories' : _selectedCategory!,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_selectedCategory != null)
                            TextButton(
                              onPressed: () => setState(() => _selectedCategory = null),
                              child: const Text('All Categories'),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Categories grid or filtered list
                    if (_selectedCategory == null)
                      _buildCategoryGrid()
                    else
                      _buildFilteredList(_selectedCategory!),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(30),
        height: 47,
        decoration: ShapeDecoration(
          color: const Color(0xFF3B82F6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBottomNavItem(Icons.home, 0),
            _buildBottomNavItem(Icons.task_alt, 1),
            _buildBottomNavItem(Icons.folder, 2),
            _buildBottomNavItem(Icons.person, 3),
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard(dynamic file) {
    if (file is! Map) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const ShapeDecoration(
              color: Colors.white,
              shape: OvalBorder(),
            ),
            child: Icon(
              _getFileIcon(file['fileType'] ?? ''),
              color: const Color(0xFF3B82F6),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file['fileName'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Outfit',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatFileSize(file['fileSize'] ?? 0),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, color: Color(0xFF10B981)),
                onPressed: () => _previewFile(file),
              ),
              IconButton(
                icon: const Icon(Icons.download, color: Color(0xFF3B82F6)),
                onPressed: () => _downloadFile(file),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteFile(file),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final items = [
      {'name': 'Documents', 'icon': Icons.description},
      {'name': 'Images', 'icon': Icons.image},
      {'name': 'Videos', 'icon': Icons.play_circle_fill},
      {'name': 'Others', 'icon': Icons.folder},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 19),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          // Reduced aspect ratio to give items a bit more vertical space
          childAspectRatio: 1.35,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final count = _fileCategories[item['name']]?.length ?? 0;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = item['name'] as String),
            child: Container(
              decoration: ShapeDecoration(
                color: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item['icon'] as IconData, size: 36, color: const Color(0xFF3B82F6)),
                  const SizedBox(height: 12),
                  Text(
                    item['name'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$count files',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilteredList(String category) {
    final files = _fileCategories[category] ?? [];
    if (files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: const [
              Icon(Icons.folder_open, size: 64, color: Color(0xFFD1D5DB)),
              SizedBox(height: 16),
              Text('No files in this category', style: TextStyle(fontFamily: 'Outfit', color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 19),
      itemCount: files.length,
      itemBuilder: (context, index) => _buildFileCard(files[index]),
    );
  }

  IconData _getFileIcon(String mimeType) {
    final ext = mimeType.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['doc','docx','xls','xlsx','ppt','pptx','txt','rtf','odt','csv'].contains(ext)) return Icons.description;
    if (['jpg','jpeg','png','gif','bmp','webp','svg','tiff'].contains(ext)) return Icons.image;
    if (['mp4','mkv','avi','mov','wmv','flv','webm'].contains(ext)) return Icons.video_file;
    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildBottomNavItem(IconData icon, int index) {
    final isSelected = _selectedBottomNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedBottomNavIndex = index);
        switch (index) {
          case 0:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
            break;
          case 1:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TasksScreen()),
            );
            break;
          case 2:
            break;
          case 3:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
            break;
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 3,
              height: 3,
              decoration: const ShapeDecoration(
                color: Colors.white,
                shape: OvalBorder(),
              ),
            ),
        ],
      ),
    );
  }
}