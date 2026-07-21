import 'package:flutter/material.dart';
import '../services/ai_report_service.dart';
import 'ai_chat_modal.dart';

class AiBriefingBottomSheet extends StatefulWidget {
  const AiBriefingBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AiBriefingBottomSheet(),
    );
  }

  @override
  State<AiBriefingBottomSheet> createState() => _AiBriefingBottomSheetState();
}

class _AiBriefingBottomSheetState extends State<AiBriefingBottomSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  AiAnalysisResponse? _analysis;

  @override
  void initState() {
    super.initState();
    _fetchAnalysis();
  }

  Future<void> _fetchAnalysis() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await AiReportService.analyzeExecutiveCockpit();
      if (mounted) {
        setState(() {
          _analysis = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
          left: BorderSide(color: Color(0xFF8B5CF6), width: 0.5),
          right: BorderSide(color: Color(0xFF8B5CF6), width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'AI Executive Cockpit',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF8B5CF6).withOpacity(0.4),
                              ),
                            ),
                            child: const Text(
                              'QWEN 2.5:3B',
                              style: TextStyle(
                                color: Color(0xFFDDD6FE),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Chuẩn đoán 8 Nhóm số liệu Thời Gian Thực',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _fetchAnalysis,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: _isLoading ? const Color(0xFF8B5CF6) : Colors.grey,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF1E293B), height: 1),

          // Body
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                    ? _buildErrorState()
                    : _buildAnalysisContent(),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF0B1120),
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      AiChatModal.show(context);
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text(
                      'Hỏi Đáp AI Trực Tiếp',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF8B5CF6)),
          const SizedBox(height: 20),
          const Text(
            '🤖 AI đang tổng hợp ma trận số liệu 8 nhóm...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Phân tích dòng tiền thực thu, Top nợ xấu & đơn hàng trễ',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.amber, size: 48),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'Lỗi kết nối tới AI',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _fetchAnalysis,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Thử Lại Ngay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisContent() {
    if (_analysis == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Highlights
          _buildSectionCard(
            title: '🟢 Điểm Sáng Vận Hành (Highlights)',
            items: _analysis!.highlights,
            borderColor: const Color(0xFF10B981),
            bgColor: const Color(0xFF064E3B).withOpacity(0.3),
            iconColor: const Color(0xFF34D399),
          ),
          const SizedBox(height: 16),

          // Section 2: Risks
          _buildSectionCard(
            title: '🔴 Rủi Ro & Điểm Nghẽn (Critical Risks)',
            items: _analysis!.risks,
            borderColor: const Color(0xFFF43F5E),
            bgColor: const Color(0xFF4C0519).withOpacity(0.3),
            iconColor: const Color(0xFFFB7185),
          ),
          const SizedBox(height: 16),

          // Section 3: Recommendations
          _buildSectionCard(
            title: '🎯 Khuyến Nghị Hành Động (Recommendations)',
            items: _analysis!.recommendations,
            borderColor: const Color(0xFF6366F1),
            bgColor: const Color(0xFF31106A).withOpacity(0.3),
            iconColor: const Color(0xFF818CF8),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<String> items,
    required Color borderColor,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: iconColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              'Không có ghi nhận đặc biệt cho phần này.',
              style: TextStyle(color: Colors.grey[400], fontSize: 12, fontStyle: FontStyle.italic),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(color: iconColor, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
