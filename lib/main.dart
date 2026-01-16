import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fpdf/pages/imgtopdf.dart';
import 'package:fpdf/pages/pdrtoword.dart';
import 'package:fpdf/pages/piccompress.dart';
import 'package:fpdf/pages/ptoimg.dart';
import 'package:fpdf/pages/wordtopdf.dart';
import 'package:url_launcher/url_launcher.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF 图片转换工具',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String? _savePath;
  final double _quality = 0.9;
  List<Widget> _buildPages() {
    return [
      PdfToImagePage(savePath: _savePath, quality: _quality),
      ImageToPdfPage(savePath: _savePath),
      WordToPdfPage(savePath: _savePath),
      PdfToWordPage(savePath: _savePath),
      ImageCompressPage(savePath: _savePath),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF 图片转换工具'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Row(
        children: [
          // 侧边栏
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.picture_as_pdf),
                selectedIcon: Icon(Icons.picture_as_pdf),
                label: Text('PDF转图片'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.image),
                selectedIcon: Icon(Icons.image),
                label: Text('图片转PDF'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.wordpress),
                selectedIcon: Icon(Icons.wordpress),
                label: Text('Word转PDF'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.description),
                selectedIcon: Icon(Icons.description),
                label: Text('PDF转Word'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.compress_outlined),
                selectedIcon: Icon(Icons.compress_outlined),
                label: Text('图片压缩'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // 主内容区
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    _savePath ?? '未选择保存路径',
                    style: TextStyle(
                      color: _savePath != null
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: openFileExplorer,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('打开文件夹'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _selectSavePath,
              icon: const Icon(Icons.folder),
              label: const Text('选择保存路径'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectSavePath() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _savePath = selectedDirectory;
      });
    }
  }

void openFileExplorer() async {
  if (_savePath == null) return;

  // 使用 Uri.file 转换路径
  // windows: true 会确保处理好盘符和反斜杠
  final Uri uri = Uri.file(_savePath!); 

  try {
    // 在 Windows 上，推荐使用 externalApplication 模式
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("打开文件夹失败: $e"),
        backgroundColor: Colors.red,
      ),
    );
  }
}
}
