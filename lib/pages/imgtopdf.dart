// 图片转 PDF 页面
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:image/image.dart' as img;
class ImageToPdfPage extends StatefulWidget {
  final String? savePath;

  const ImageToPdfPage({super.key, required this.savePath});

  @override
  State<ImageToPdfPage> createState() => _ImageToPdfPageState();
}

class _ImageToPdfPageState extends State<ImageToPdfPage> {
  List<String> _imagePaths = [];
  bool _isProcessing = false;
  String _statusMessage = '';

  Future<void> _selectImages() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _imagePaths = result.files
            .where((file) => file.path != null)
            .map((file) => file.path!)
            .toList();
        _statusMessage = '已选择 ${_imagePaths.length} 张图片';
      });
    }
  }

  Future<void> _convertImagesToPdf() async {
    if (_imagePaths.isEmpty) {
      _showMessage('请先选择图片文件');
      return;
    }

    if (widget.savePath == null) {
      _showMessage('请先选择保存路径');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = '正在转换...';
    });

    try {
      final pdf = pw.Document();

      for (int i = 0; i < _imagePaths.length; i++) {
        final imageFile = File(_imagePaths[i]);
        final imageBytes = await imageFile.readAsBytes();
        final image = img.decodeImage(imageBytes);

        if (image != null) {
          // 将图片转换为 PDF 格式
          final pdfImage = pw.MemoryImage(imageBytes);

          // 计算页面尺寸（保持图片宽高比）
          final pageWidth = PdfPageFormat.a4.width;
          final pageHeight = PdfPageFormat.a4.height;
          final imageWidth = image.width.toDouble();
          final imageHeight = image.height.toDouble();

          // 计算缩放比例以适应页面
          final widthRatio = pageWidth / imageWidth;
          final heightRatio = pageHeight / imageHeight;
          final ratio = widthRatio < heightRatio ? widthRatio : heightRatio;

          final scaledWidth = imageWidth * ratio;
          final scaledHeight = imageHeight * ratio;

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Image(
                    pdfImage,
                    width: scaledWidth,
                    height: scaledHeight,
                  ),
                );
              },
            ),
          );
        }
      }

      // 保存 PDF
      final fileName = _imagePaths.length == 1
          ? '${path.basenameWithoutExtension(_imagePaths[0])}.pdf'
          : 'merged_images_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outputPath = path.join(widget.savePath!, fileName);
      final file = File(outputPath);
      await file.writeAsBytes(await pdf.save());

      setState(() {
        _statusMessage = '转换完成！已生成: $fileName';
        _isProcessing = false;
      });

      _showMessage('转换成功！', isError: false);
    } catch (e) {
      setState(() {
        _statusMessage = '转换失败: $e';
        _isProcessing = false;
      });
      _showMessage('转换失败: $e');
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

  void _removeImage(int index) {
    setState(() {
      _imagePaths.removeAt(index);
      _statusMessage = '已选择 ${_imagePaths.length} 张图片';
    });
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
                    '图片转 PDF',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '选择一张或多张图片，合并转换为 PDF 文件',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 文件选择
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _selectImages,
                    icon: const Icon(Icons.image),
                    label: const Text('选择图片（可多选）'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  if (_imagePaths.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _imagePaths.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const Icon(Icons.image),
                            title: Text(
                              path.basename(_imagePaths[index]),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _isProcessing
                                  ? null
                                  : () => _removeImage(index),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // 转换按钮
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _convertImagesToPdf,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf),
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              )),
          ),
        ],
      ),
    );
  }
}
