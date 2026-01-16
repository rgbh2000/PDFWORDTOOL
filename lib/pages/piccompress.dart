import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
// 压缩参数模型
class _CompressParams {
  final Uint8List bytes;
  final int quality;
  _CompressParams(this.bytes, this.quality);
}

// 核心图片处理函数（运行在独立 Isolate 中）
Uint8List _doCompression(_CompressParams params) {
  final img.Image? image = img.decodeImage(params.bytes);
  if (image == null) throw Exception("无法解码图片");

  // 执行 JPG 编码压缩
  final List<int> compressed = img.encodeJpg(image, quality: params.quality);
  return Uint8List.fromList(compressed);
}
class ImageCompressPage extends StatefulWidget {
  final String? savePath;

  const ImageCompressPage({
    super.key,
    required this.savePath,
  });

  @override
  State<ImageCompressPage> createState() => _ImageCompressPageState();
}

class _ImageCompressPageState extends State<ImageCompressPage> {
  List<File> _selectedFiles = [];
  double _quality = 80.0;
  String _status = "等待操作";
  int _currentProcessIndex = 0;
  bool _isCompressing = false;
  bool _isCanceled = false;

  // 智能文件大小转换
  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    double num = bytes / math.pow(1024, i);
    return "${num.toStringAsFixed(1)} ${suffixes[i]}";
  }

  // 选择文件
  void _selectFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result != null) {
      setState(() {
        _selectedFiles = result.paths.map((path) => File(path!)).toList();
        _status = "已选择 ${_selectedFiles.length} 张图片";
        _currentProcessIndex = 0;
        _isCanceled = false;
      });
    }
  }

  // 核心压缩与保存逻辑
  Future<void> _compressAndSave() async {
    if (_selectedFiles.isEmpty || widget.savePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请检查保存路径并选择文件")),
      );
      return;
    }

    setState(() {
      _isCompressing = true;
      _isCanceled = false;
      _status = "准备中...";
    });

    for (int i = 0; i < _selectedFiles.length; i++) {
      // 检查点 1: 开始前
      if (_isCanceled) break;

      final File file = _selectedFiles[i];
      final String fileName = p.basename(file.path);

      setState(() {
        _currentProcessIndex = i + 1;
        _status = "正在压缩: $fileName";
      });

      try {
        final Uint8List bytes = await file.readAsBytes();
        
        // 检查点 2: 读取完大字节流后
        if (_isCanceled) break;

        final Uint8List compressedBytes = await compute(_doCompression, _CompressParams(
          bytes,
          _quality.toInt(),
        ));

        // 检查点 3: 耗时计算返回后
        if (_isCanceled) break;

        final String savePath = p.join(widget.savePath!, "min_$fileName");
        await File(savePath).writeAsBytes(compressedBytes);
        
      } catch (e) {
        debugPrint("压缩出错: $e");
      }
    }

    setState(() {
      _isCompressing = false;
      if (_isCanceled) {
        _status = "压缩已停止";
      } else {
        _status = "全部压缩完成！";
        _selectedFiles = [];
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_status), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // 顶部控制卡片
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildHeaderCard(theme),
            ),
          ),
          // 列表预览
          if (_selectedFiles.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildFileItem(_selectedFiles[index]),
                  childCount: _selectedFiles.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildActionButtons(),
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(_status, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            if (_isCompressing) ...[
              LinearProgressIndicator(
                value: _selectedFiles.isEmpty ? 0 : _currentProcessIndex / _selectedFiles.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text("进度: $_currentProcessIndex / ${_selectedFiles.length}"),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.tune, color: Colors.blueAccent),
                  Expanded(
                    child: Slider(
                      value: _quality,
                      min: 10,
                      max: 100,
                      divisions: 9,
                      label: "压缩质量: ${_quality.round()}%",
                      onChanged: (v) => setState(() => _quality = v),
                    ),
                  ),
                  Text("${_quality.round()}%", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileItem(File file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        leading: const Icon(Icons.image_outlined, color: Colors.blueAccent),
        title: Text(p.basename(file.path), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(_formatFileSize(file.lengthSync())),
        trailing: _isCompressing
            ? null
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                onPressed: () => setState(() => _selectedFiles.remove(file)),
              ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isCompressing) {
      return FloatingActionButton.extended(
        onPressed: () => setState(() => _isCanceled = true),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text("停止压缩"),
      );
    }

    if (_selectedFiles.isEmpty) {
      return FloatingActionButton.extended(
        onPressed: _selectFiles,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text("选择图片"),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FloatingActionButton.extended(
          onPressed: () => setState(() => _selectedFiles = []),
          heroTag: "clearBtn",
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          label: const Text("清空"),
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
        const SizedBox(width: 16),
        FloatingActionButton.extended(
          onPressed: _compressAndSave,
          heroTag: "startBtn",
          label: const Text("开始压缩"),
          icon: const Icon(Icons.bolt_rounded),
        ),
      ],
    );
  }
}