import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dashboard.dart';
import 'task_screen.dart';
import 'team_screen.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  int _selectedBottomNavIndex = 2; // Files tab is selected

  final List<Map<String, dynamic>> _fileCategories = [
    {
      'title': 'Documents',
      'count': '24 files',
      'icon': 'assets/images/document_icon.png',
    },
    {
      'title': 'Images',
      'count': '18 files',
      'icon': 'assets/images/image_icon.png',
    },
    {
      'title': 'Videos',
      'count': '12 files',
      'icon': 'assets/images/video_icon.png',
    },
    {
      'title': 'Others',
      'count': '8 files',
      'icon': 'assets/images/other_icon.png',
    },
  ];

  final List<Map<String, dynamic>> _recentFiles = [
    {
      'name': 'project-specs.pdf',
      'uploadedBy': 'Michelle Juanico',
      'size': '2.5 MB',
      'time': '2 hours ago',
      'icon': Icons.picture_as_pdf,
    },
    {
      'name': 'wireframes.fig',
      'uploadedBy': 'Joeross Palabrica',
      'size': '2.5 MB',
      'time': '2 hours ago',
      'icon': Icons.design_services,
    },
    {
      'name': 'team-photo.jpg',
      'uploadedBy': 'Allyn Ledesma',
      'size': '2.5 MB',
      'time': '2 hours ago',
      'icon': Icons.image,
    },
    {
      'name': 'API Documentation',
      'uploadedBy': 'Lean Cabales',
      'size': '2.5 MB',
      'time': '2 hours ago',
      'icon': Icons.description,
    },
  ];

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        // Handle selected files
        List<PlatformFile> files = result.files;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${files.length} file(s) selected'),
            backgroundColor: const Color(0xFF3B82F6),
          ),
        );
      }
    } catch (e) {
      print('Error picking files: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
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
                        Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined),
                              onPressed: () {},
                            ),
                            Positioned(
                              right: 12,
                              top: 12,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const ShapeDecoration(
                                  color: Color(0xFF3EB9AF),
                                  shape: OvalBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: ShapeDecoration(
                            color: const Color(0xFFE2E8F0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.asset(
                              'assets/images/profilepic.png',
                              fit: BoxFit.cover,
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
                          'Tap to select files or drag & drop',
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

              // File Categories Header
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 19),
                child: Text(
                  'File Categories',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // File Categories Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 19),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 1.48,
                  ),
                  itemCount: _fileCategories.length,
                  itemBuilder: (context, index) {
                    final category = _fileCategories[index];
                    return _buildFileCategoryCard(
                      title: category['title'],
                      count: category['count'],
                      icon: category['icon'],
                    );
                  },
                ),
              ),

              const SizedBox(height: 25),

              // Recent Files Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 19),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Files',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'See all',
                        style: TextStyle(
                          color: Color(0xFF3B82F6),
                          fontSize: 14,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Recent Files List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 19),
                itemCount: _recentFiles.length,
                itemBuilder: (context, index) {
                  final file = _recentFiles[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildRecentFileCard(
                      name: file['name'],
                      uploadedBy: file['uploadedBy'],
                      size: file['size'],
                      time: file['time'],
                      icon: file['icon'],
                    ),
                  );
                },
              ),

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

  Widget _buildFileCategoryCard({
  required String title,
  required String count,
  required String icon,
}) {
  return GestureDetector(
    onTap: () {
      // Navigate to category details
      print('Open $title category');
    },
    child: Container(
      decoration: ShapeDecoration(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    icon,
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count,
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 14,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              width: 15,
              height: 15,
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              child: const Icon(
                Icons.more_vert,
                size: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildRecentFileCard({
    required String name,
    required String uploadedBy,
    required String size,
    required String time,
    required IconData icon,
  }) {
    return Container(
      height: 104,
      decoration: ShapeDecoration(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                icon,
                color: Colors.black,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'by $uploadedBy',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$size | $time',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.download_rounded,
                color: Color(0xFF64748B),
                size: 24,
              ),
              onPressed: () {
                // Show file options menu
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, int index) {
    final isSelected = _selectedBottomNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBottomNavIndex = index;
        });
        // Handle navigation based on index
        switch (index) {
        case 0:
          // Navigate to HomeScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
          break;

        case 1:
          // Navigate to TasksScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => TasksScreen()),
          );
          break;

        case 2:
          // Already on FilesScreen — do nothing
          
          break;
        case 3:
          // Navigate to TeamScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => TeamScreen()),
          );
          break;
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
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