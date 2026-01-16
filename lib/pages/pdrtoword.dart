import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class PdfToWordPage extends StatefulWidget {
  final String? savePath;

  const PdfToWordPage({super.key, required this.savePath});

  @override
  State<PdfToWordPage> createState() => _PdfToWordPageState();
}

class _PdfToWordPageState extends State<PdfToWordPage> {
  String? _pdfPath;
  bool _isProcessing = false;
  String _statusMessage = '';

  // 选择 PDF 文件
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

  // 执行转换逻辑 (PDF -> Word)
  Future<void> _convertPdfToWord() async {
    if (_pdfPath == null || widget.savePath == null) {
      _showMessage('请先选择文件和保存路径');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Word 正在解析 PDF 布局并转换...';
    });

    final String inputPath = _pdfPath!.replaceAll('/', '\\');
    final String outputName = "${path.basenameWithoutExtension(_pdfPath!)}.docx";
    final String outputPath = path.join(widget.savePath!, outputName).replaceAll('/', '\\');

    try {
      // PowerShell 脚本逻辑：
      // 1. 打开 PDF
      // 2. 另存为 wdFormatXMLDocument (16) 也就是 .docx
      final shellCommand = '''
      try {
        \$word = New-Object -ComObject Word.Application -ErrorAction Stop
        \$word.Visible = \$false
        # 打开 PDF
        \$doc = \$word.Documents.Open("$inputPath", \$false, \$true)
        # 16 代表 .docx 格式
        \$doc.SaveAs([ref] "$outputPath", [ref] 16)
        \$doc.Close()
        \$word.Quit()
        exit 0
      } catch {
        if (\$word) { \$word.Quit() }
        write-error \$_.Exception.Message
        exit 1
      }
      ''';

      final result = await Process.run('powershell', ['-Command', shellCommand]);

      if (result.exitCode == 0) {
        setState(() {
          _statusMessage = '转换成功！\n文件已保存至: $outputPath';
          _isProcessing = false;
        });
        _showMessage('转换成功！', isError: false);
      } else {
        throw Exception(result.stderr);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showErrorDialog(e.toString());
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('转换失败'),
        content: Text('错误详情：$error\n\n请确保电脑已安装 Microsoft Word 2013 及以上版本。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
        ],
      ),
    );
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
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('PDF 转 Word', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('利用 Word 引擎将 PDF 还原为可编辑的 Docx 文档。', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              
              // 选择文件按钮
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _selectPdfFile,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('选择 PDF 文件'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),

              if (_pdfPath != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                  child: Text('待转换: ${path.basename(_pdfPath!)}'),
                ),
              ],

              const SizedBox(height: 24),

              // 执行按钮
              ElevatedButton.icon(
                onPressed: _isProcessing || _pdfPath == null ? null : _convertPdfToWord,
                icon: _isProcessing 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.swap_horiz),
                label: Text(_isProcessing ? '正在转换...' : '开始转换'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),

              if (_statusMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                SelectableText(_statusMessage, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}