import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class WordToPdfPage extends StatefulWidget {
  final String? savePath;

  const WordToPdfPage({super.key, required this.savePath});

  @override
  State<WordToPdfPage> createState() => _WordToPdfPageState();
}

class _WordToPdfPageState extends State<WordToPdfPage> {
  String? _wordPath;
  bool _isProcessing = false;
  String _statusMessage = '';

  Future<void> _selectWordFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'doc'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _wordPath = result.files.single.path;
        _statusMessage = '已选择: ${path.basename(_wordPath!)}';
      });
    }
  }

  Future<void> _convertWordToPdf() async {
    if (_wordPath == null || widget.savePath == null) {
      _showMessage('请先选择文件和保存路径');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = '正在启动 Word 引擎进行完美转换...';
    });

    final String inputPath = _wordPath!.replaceAll('/', '\\');
    final String outputName = "${path.basenameWithoutExtension(_wordPath!)}.pdf";
    final String outputPath = path.join(widget.savePath!, outputName).replaceAll('/', '\\');

    try {
      // 优化的 PowerShell 脚本：
      // 1. 使用 ExportAsFixedFormat 代替 SaveAs (更稳定)
      // 2. 显式处理 COM 对象的释放，防止进程残留
      final shellCommand = '''
      try {
        \$word = New-Object -ComObject Word.Application -ErrorAction Stop
        \$word.Visible = \$false
        \$doc = \$word.Documents.Open("$inputPath", \$false, \$true)
        # 17 是 wdFormatPDF
        \$doc.ExportAsFixedFormat("$outputPath", 17)
        \$doc.Close(0)
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
      _showRepairDialog(e.toString());
    }
  }

  // 当配置有误时，弹出专业的修复提示
  void _showRepairDialog(String errorDetail) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Word 引擎配置有误'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('检测到您的 Word 组件调用失败，可能是由于 Office 安装损坏或版本冲突导致的。'),
            const SizedBox(height: 12),
            const Text('建议尝试以下步骤修复：', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('1. 打开“控制面板” > “程序和功能”'),
            const Text('2. 找到 Microsoft Office，点击“更改”'),
            const Text('3. 选择“快速修复”并重启程序'),
            if (errorDetail.contains('0x80029C4A')) 
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('提示：检测到特定错误 0x80029C4A，这通常是多版本 Office 冲突引起的。', 
                  style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('好的')),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green),
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
              const Text('Word 转 PDF', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('利用本地 Word 引擎转换，完美保留图片、表格和排版。', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _selectWordFile,
                icon: const Icon(Icons.description),
                label: const Text('选择 Word 文件 (.docx / .doc)'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
              if (_wordPath != null) ...[
                const SizedBox(height: 16),
                Text('当前选择: ${path.basename(_wordPath!)}', style: const TextStyle(color: Colors.blueGrey)),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isProcessing || _wordPath == null ? null : _convertWordToPdf,
                icon: _isProcessing 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
                SelectableText(_statusMessage, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}