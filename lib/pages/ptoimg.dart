// PDF 转图片页面
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class PdfToImagePage extends StatefulWidget {
  final String? savePath;
  final double quality;

  const PdfToImagePage({
    super.key,
    required this.savePath,
    required this.quality,
  });

  @override
  State<PdfToImagePage> createState() => _PdfToImagePageState();
}

class _PdfToImagePageState extends State<PdfToImagePage> {
  String? _pdfPath;
  bool _isProcessing = false;
  String _statusMessage = '';
  double _quality = 0.9;

  @override
  void initState() {
    super.initState();
    _quality = widget.quality;
  }

  @override
  void didUpdateWidget(PdfToImagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _quality = widget.quality;
  }

  Future<void> _selectPdfFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pdfPath = result.files.single.path;
        _statusMessage = '已选择: ${path.basename(_pdfPath!)}';
      });
    }
  }

  Future<void> _convertPdfToImages() async {
    if (_pdfPath == null || widget.savePath == null) {
      _showMessage('请检查文件和保存路径');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = '正在转换...';
    });

    try {
      final pdfxDoc = await pdfx.PdfDocument.openFile(_pdfPath!);
      final pageCount = pdfxDoc.pagesCount;

      final scale = 1.0 + (_quality * 2.0);
      for (int i = 0; i < pageCount; i++) {
        final page = await pdfxDoc.getPage(i + 1);

        final pageImage = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: pdfx.PdfPageImageFormat.jpeg, // 修正此处
        );

        if (pageImage != null) {
          // 确保您已经导入了 'dart:io'
          final String fileName = "page_${i + 1}.jpg";
          final String filePath = path.join(widget.savePath!, fileName);
          final File file = File(filePath);
          await file.writeAsBytes(pageImage.bytes); // 保存字节流
        }
        await page.close();
      }
      await pdfxDoc.close();

      setState(() {
        _statusMessage = '转换完成！已保存到: ${widget.savePath}';
        _isProcessing = false;
      });
      _showMessage('转换成功！', isError: false);
    } catch (e) {
      setState(() {
        _statusMessage = '错误: $e';
        _isProcessing = false;
      });
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'PDF 转图片',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '选择 PDF 文件并设置图片质量，然后转换为图片',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  // 质量设置
                  Row(
                    children: [
                      const Text('图片质量: '),
                      Expanded(
                        child: Slider(
                          value: _quality,
                          min: 0.1,
                          max: 1.0,
                          divisions: 18,
                          label: '${(_quality * 100).toInt()}%',
                          onChanged: (value) {
                            setState(() {
                              _quality = value;
                            });
                          },
                        ),
                      ),
                      Text('${(_quality * 100).toInt()}%'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 文件选择
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _selectPdfFile,
                    icon: const Icon(Icons.insert_drive_file),
                    label: const Text('选择 PDF 文件'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  if (_pdfPath != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              path.basename(_pdfPath!),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // 转换按钮
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _convertPdfToImages,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.transform),
                    label: Text(_isProcessing ? '转换中...' : '开始转换'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (_statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
