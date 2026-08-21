import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerScreen extends StatefulWidget {
  final String? pdfUrl;
  final String? filePath;
  final String title;
  final bool allowDownload;

  const PdfViewerScreen({
    super.key,
    this.pdfUrl,
    this.filePath,
    this.title = 'PDF Document',
    this.allowDownload = true,
  }) : assert(
          pdfUrl != null || filePath != null,
          'Either pdfUrl or filePath must be provided.',
        );

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final PdfViewerController _pdfViewerController;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey<SfPdfViewerState>();

  int _pageCount = 0;
  int _currentPage = 1;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDownloading = false;
  double _zoomLevel = 1.0;
  PdfPageLayoutMode _layoutMode = PdfPageLayoutMode.continuous;
  PdfScrollDirection _scrollDirection = PdfScrollDirection.vertical;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final nextZoom = (_pdfViewerController.zoomLevel + 0.25).clamp(1.0, 3.0);
    _pdfViewerController.zoomLevel = nextZoom;
    setState(() => _zoomLevel = nextZoom);
  }

  void _zoomOut() {
    final nextZoom = (_pdfViewerController.zoomLevel - 0.25).clamp(1.0, 3.0);
    _pdfViewerController.zoomLevel = nextZoom;
    setState(() => _zoomLevel = nextZoom);
  }

  void _resetZoom() {
    _pdfViewerController.zoomLevel = 1.0;
    setState(() => _zoomLevel = 1.0);
  }

  void _previousPage() {
    if (_currentPage > 1) {
      _pdfViewerController.previousPage();
    }
  }

  void _nextPage() {
    if (_currentPage < _pageCount) {
      _pdfViewerController.nextPage();
    }
  }

  Future<void> _showJumpToPageDialog() async {
    if (_pageCount <= 1) return;

    final controller = TextEditingController(text: '$_currentPage');
    final selectedPage = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Jump to Page'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Page Number',
              hintText: '1 - $_pageCount',
              border: const OutlineInputBorder(),
              suffixText: '/ $_pageCount',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final page = int.tryParse(controller.text.trim());
                if (page != null && page >= 1 && page <= _pageCount) {
                  Navigator.pop(ctx, page);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a page between 1 and $_pageCount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );

    if (selectedPage != null && mounted) {
      _pdfViewerController.jumpToPage(selectedPage);
    }
  }

  Future<void> _downloadPdf() async {
    if (_isDownloading) return;

    setState(() => _isDownloading = true);

    try {
      Uint8List bytes;
      String fileName = widget.title.trim();
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        fileName = '$fileName.pdf';
      }
      fileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

      if (widget.pdfUrl != null && widget.pdfUrl!.isNotEmpty) {
        final response = await http.get(Uri.parse(widget.pdfUrl!));
        if (response.statusCode != 200) {
          throw Exception('Failed to download PDF (HTTP ${response.statusCode})');
        }
        bytes = response.bodyBytes;
      } else if (widget.filePath != null) {
        final file = File(widget.filePath!);
        if (!file.existsSync()) {
          throw Exception('Local file not found.');
        }
        bytes = await file.readAsBytes();
      } else {
        throw Exception('No valid PDF source provided.');
      }

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: bytes,
      );

      if (savePath == null || savePath.trim().isEmpty) {
        return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saved to: $savePath',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!_isLoading && _pageCount > 0)
              Text(
                'Page $_currentPage of $_pageCount',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2563EB),
                Color(0xFF7C3AED),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Zoom in',
            icon: const Icon(Icons.zoom_in),
            onPressed: _isLoading ? null : _zoomIn,
          ),
          IconButton(
            tooltip: 'Zoom out',
            icon: const Icon(Icons.zoom_out),
            onPressed: _isLoading ? null : _zoomOut,
          ),
          if (widget.allowDownload)
            IconButton(
              tooltip: 'Download PDF',
              icon: _isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              onPressed: _isLoading || _isDownloading ? null : _downloadPdf,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onSelected: (value) {
              switch (value) {
                case 'jump':
                  _showJumpToPageDialog();
                  break;
                case 'reset_zoom':
                  _resetZoom();
                  break;
                case 'toggle_layout':
                  setState(() {
                    _layoutMode = _layoutMode == PdfPageLayoutMode.continuous
                        ? PdfPageLayoutMode.single
                        : PdfPageLayoutMode.continuous;
                  });
                  break;
                case 'toggle_direction':
                  setState(() {
                    _scrollDirection = _scrollDirection == PdfScrollDirection.vertical
                        ? PdfScrollDirection.horizontal
                        : PdfScrollDirection.vertical;
                  });
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'jump',
                child: Row(
                  children: [
                    Icon(Icons.find_in_page_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Jump to page'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reset_zoom',
                child: Row(
                  children: [
                    const Icon(Icons.restart_alt_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text('Reset zoom (${(_zoomLevel * 100).toInt()}%)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_layout',
                child: Row(
                  children: [
                    const Icon(Icons.view_agenda_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text(_layoutMode == PdfPageLayoutMode.continuous
                        ? 'Single Page Mode'
                        : 'Continuous Scroll'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_direction',
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text(_scrollDirection == PdfScrollDirection.vertical
                        ? 'Horizontal Scroll'
                        : 'Vertical Scroll'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load PDF document',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          else if (widget.pdfUrl != null && widget.pdfUrl!.isNotEmpty)
            SfPdfViewer.network(
              widget.pdfUrl!,
              key: _pdfViewerKey,
              controller: _pdfViewerController,
              pageLayoutMode: _layoutMode,
              scrollDirection: _scrollDirection,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              enableDoubleTapZooming: true,
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _pageCount = details.document.pages.count;
                  });
                }
              },
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _errorMessage = details.description;
                  });
                }
              },
              onPageChanged: (PdfPageChangedDetails details) {
                if (mounted) {
                  setState(() {
                    _currentPage = details.newPageNumber;
                  });
                }
              },
            )
          else if (widget.filePath != null && widget.filePath!.isNotEmpty)
            SfPdfViewer.file(
              File(widget.filePath!),
              key: _pdfViewerKey,
              controller: _pdfViewerController,
              pageLayoutMode: _layoutMode,
              scrollDirection: _scrollDirection,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              enableDoubleTapZooming: true,
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _pageCount = details.document.pages.count;
                  });
                }
              },
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _errorMessage = details.description;
                  });
                }
              },
              onPageChanged: (PdfPageChangedDetails details) {
                if (mounted) {
                  setState(() {
                    _currentPage = details.newPageNumber;
                  });
                }
              },
            ),

          // Loading Overlay
          if (_isLoading && _errorMessage == null)
            Container(
              color: theme.scaffoldBackgroundColor,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 18),
                    Text(
                      'Loading document...',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Floating Navigation Bar (Page Jump / Navigation)
          if (!_isLoading && _pageCount > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  elevation: 6,
                  shadowColor: Colors.black38,
                  borderRadius: BorderRadius.circular(30),
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white.withValues(alpha: 0.95),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Previous page',
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _currentPage > 1 ? _previousPage : null,
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _showJumpToPageDialog,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Text(
                              '$_currentPage / $_pageCount',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next page',
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _currentPage < _pageCount ? _nextPage : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
