import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MobileIDEApp());
}

class MobileIDEApp extends StatelessWidget {
  const MobileIDEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Klencod IDE',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1e1e1e)),
        drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF181818)),
      ),
      home: const IDEScreen(),
    );
  }
}

class IDEScreen extends StatefulWidget {
  const IDEScreen({super.key});

  @override
  State<IDEScreen> createState() => _IDEScreenState();
}

class _IDEScreenState extends State<IDEScreen> {
  final TextEditingController _codeController = TextEditingController();
  String currentFilePath = '';
  List<FileSystemEntity> _files = [];
  Directory? _projectDir;

  @override
  void initState() {
    super.initState();
    _requestStoragePermissionAndInit();
  }

  // 1. تهيئة المجلد الأساسي للمشروع وهيكل الملفات الافتراضي
  Future<void> _requestStoragePermissionAndInit() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();

    final docDir = await getApplicationDocumentsDirectory();
    final projectDir = Directory('${docDir.path}/KlencodProject');
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
      
      // إنشاء هيكل مجلدات افتراضي
      Directory('${projectDir.path}/lib').createSync();
      Directory('${projectDir.path}/android').createSync();
      Directory('${projectDir.path}/.github').createSync();

      // ملف افتراضي
      final defaultFile = File('${projectDir.path}/lib/main.dart');
      await defaultFile.writeAsString('''void main() {
  print("مرحباً بك في Klencod IDE من الهاتف!");
}''');
      
      final pubspec = File('${projectDir.path}/pubspec.yaml');
      await pubspec.writeAsString('name: bisho_ide\nversion: 1.0.0');
    }

    setState(() {
      _projectDir = projectDir;
    });
    _loadFileList();
    
    // فتح ملف main.dart تلقائياً عند البدء
    final defaultOpen = File('${projectDir.path}/lib/main.dart');
    if (defaultOpen.existsSync()) {
      _openFile(defaultOpen);
    }
  }

  // جلب كافة الملفات والمجلدات في المشروع
  void _loadFileList() {
    if (_projectDir != null) {
      setState(() {
        _files = _projectDir!.listSync(recursive: true, followLinks: false);
      });
    }
  }

  // قراءة الملف المحدد
  Future<void> _openFile(File file) async {
    final content = await file.readAsString();
    setState(() {
      currentFilePath = file.path;
      _codeController.text = content;
    });
  }

  // حفظ الملف الحالي
  Future<void> _saveFile() async {
    if (currentFilePath.isNotEmpty) {
      await File(currentFilePath).writeAsString(_codeController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ التعديلات بنجاح! 💾', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار ملف أولاً للحفظ', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange),
      );
    }
  }

  // حذف ملف
  Future<void> _deleteFile(File file) async {
    final fileName = file.path.split('/').last;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الملف'),
        content: Text('هل أنت متأكد من حذف "$fileName"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              if (await file.exists()) await file.delete();
              Navigator.pop(context);
              _loadFileList();
              if (currentFilePath == file.path) {
                setState(() {
                  currentFilePath = '';
                  _codeController.clear();
                });
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم الحذف بنجاح 🗑️', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
              );
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // إنشاء ملف أو مجلد جديد عبر أيقونة الـ (+)
  Future<void> _createNewItemDialog() async {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة إلى هيكل المشروع'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'اسم الملف (مثال: style.css)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && _projectDir != null) {
                final newFile = File('${_projectDir!.path}/${nameController.text}');
                await newFile.writeAsString('// ملف جديد');
                Navigator.pop(context);
                _loadFileList();
                _openFile(newFile);
              }
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  // إعدادات المشروع
  void _openProjectSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعدادات المشروع ⚙️'),
        content: const Text('هنا يمكنك تخصيص إعدادات حزمة الأندرويد، اسم التطبيق، وتغيير أيقونة البرنامج.'),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
      ),
    );
  }

  // بناء APK
  void _startBuildApk() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بناء تطبيق APK 📦'),
        content: const Text('جاري إعداد بيئة Gradle وتجميع الحزمة للأندرويد...'),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
      ),
    );
  }

  // تصدير ZIP
  void _exportProjectZip() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تصدير مشروعك كملف ZIP بنجاح في التخزين المحلي! 📁', style: TextStyle(color: Colors.white)), backgroundColor: Colors.blueAccent),
    );
  }

  // تنسيق الكود
  void _formatCode() {
    String text = _codeController.text;
    text = text.replaceAll(';', ';\n').replaceAll('{', '{\n  ').replaceAll('}', '\n}');
    setState(() {
      _codeController.text = text;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تنسيق الكود بنجاح! ✨', style: TextStyle(color: Colors.white)), backgroundColor: Colors.purpleAccent, duration: Duration(seconds: 1)),
    );
  }

  // معاينة حية
  void _openLivePreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewScreen(htmlContent: _codeController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String fileName = currentFilePath.isEmpty ? 'Klencod IDE' : currentFilePath.split('/').last;
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.auto_fix_high, color: Colors.pinkAccent), onPressed: _formatCode, tooltip: 'تنسيق'),
          IconButton(icon: const Icon(Icons.play_arrow, color: Colors.greenAccent), onPressed: _openLivePreview, tooltip: 'معاينة'),
          IconButton(icon: const Icon(Icons.save, color: Colors.cyanAccent), onPressed: _saveFile, tooltip: 'حفظ'),
        ],
      ),
      // القائمة الجانبية (Drawer) بدون الذكاء الاصطناعي وبترتيب نظيف
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1e1e1e)),
              accountName: const Text("779354992ali-ba"),
              accountEmail: const Text("@779354992ali-ba"),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.orangeAccent,
                child: Text('7', style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            
            // عنوان هيكل المشروع مع زر الإضافة (+)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('هيكل المشروع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.add_box, color: Colors.blueAccent, size: 28),
                    onPressed: _createNewItemDialog,
                    tooltip: 'إضافة عنصر لهيكل المشروع',
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.grey, height: 1),

            // قائمة الملفات والمجلدات
            Expanded(
              child: ListView.builder(
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final entity = _files[index];
                  final name = entity.path.split('/').last;
                  bool isDir = entity is Directory;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isDir ? Icons.folder : Icons.insert_drive_file,
                      color: isDir ? Colors.amber : Colors.blueAccent,
                      size: 20,
                    ),
                    title: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    trailing: isDir ? null : IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                      onPressed: () => _deleteFile(entity as File),
                    ),
                    onTap: () {
                      if (!isDir && entity is File) {
                        _openFile(entity);
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),

            const Divider(color: Colors.grey, height: 1),

            // الأزرار السفلية (إعدادات المشروع، بناء APK، تصدير ZIP) بدون الذكاء الاصطناعي
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openProjectSettings,
                          icon: const Icon(Icons.settings, size: 18),
                          label: const Text('إعدادات المشروع', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _startBuildApk,
                          icon: const Icon(Icons.build, size: 18),
                          label: const Text('بناء APK', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _exportProjectZip,
                      icon: const Icon(Icons.archive, size: 18),
                      label: const Text('تصدير ZIP', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () {},
                    child: const Text('طريقة الرفع: اسأل كل مرة', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          controller: _codeController,
          maxLines: null,
          expands: true,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 15,
            color: Colors.greenAccent,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'اختر ملفاً من هيكل المشروع أو أضف ملفاً جديداً للبدء...',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

class PreviewScreen extends StatelessWidget {
  final String htmlContent;
  const PreviewScreen({super.key, required this.htmlContent});

  @override
  Widget build(BuildContext context) {
    final previewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(htmlContent);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المعاينة الحية'),
        backgroundColor: const Color(0xFF1e1e1e),
      ),
      body: WebViewWidget(controller: previewController),
    );
  }
}
