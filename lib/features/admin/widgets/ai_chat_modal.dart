import 'package:flutter/material.dart';
import '../services/ai_report_service.dart';

class AiChatModal extends StatefulWidget {
  const AiChatModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AiChatModal(),
    );
  }

  @override
  State<AiChatModal> createState() => _AiChatModalState();
}

class _AiChatModalState extends State<AiChatModal> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<AiChatMessage> _messages = [
    AiChatMessage(
      id: 'init-1',
      role: 'assistant',
      content:
          'Xin chào! Tôi là Trợ lý AI Quản trị (Powered by qwen2.5:3b). Bạn cần hỏi gì về doanh thu, nợ xấu hay tiến độ đơn hàng/bếp trung tâm hôm nay?',
      timestamp: 'Vừa xong',
    ),
  ];

  bool _isThinking = false;

  final List<String> _quickSuggestions = [
    'Cửa hàng nào nợ nhiều nhất?',
    'Tỷ lệ giao thành công chuỗi là bao nhiêu?',
    'Có đơn đặt hàng chờ duyệt quá 4h không?',
    'Sản xuất bếp trung tâm hiện tại thế nào?',
  ];

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? queryText]) async {
    final text = queryText ?? _controller.text.trim();
    if (text.isEmpty || _isThinking) return;

    if (queryText == null) _controller.clear();

    final userMsg = AiChatMessage(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: text,
      timestamp: 'Bây giờ',
    );

    setState(() {
      _messages.add(userMsg);
      _isThinking = true;
    });
    _scrollToBottom();

    try {
      final chatHistory = _messages
          .skip(_messages.length > 7 ? _messages.length - 7 : 0)
          .map((m) => '${m.role == 'user' ? 'Quản lý' : 'AI'}: ${m.content}')
          .join('\n');

      final response = await AiReportService.chatWithExecutiveData(
        question: text,
        chatHistory: chatHistory,
      );

      if (mounted) {
        setState(() {
          _messages.add(
            AiChatMessage(
              id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
              role: 'assistant',
              content: response.answer,
              timestamp: 'Bây giờ',
            ),
          );
          _isThinking = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            AiChatMessage(
              id: 'err-${DateTime.now().millisecondsSinceEpoch}',
              role: 'assistant',
              content:
                  '⚠️ Lỗi phản hồi từ AI (${e.toString().replaceAll("Exception: ", "")}). Vui lòng thử lại.',
              timestamp: 'Bây giờ',
            ),
          );
          _isThinking = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
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
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trợ Lý AI Hỏi Đáp Điều Hành',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Tra cứu theo dữ liệu 8 nhóm chuỗi CKMS',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Quick suggestions
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _quickSuggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final q = _quickSuggestions[index];
                return ActionChip(
                  label: Text(
                    q,
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFF334155)),
                  onPressed: () => _sendMessage(q),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF1E293B), height: 1),

          // Chat history
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildThinkingIndicator();
                }
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF0B1120),
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Hỏi AI về công nợ, đơn hàng, vận chuyển...',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isThinking ? null : () => _sendMessage(),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: _isThinking
                          ? Colors.grey[800]
                          : const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
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

  Widget _buildThinkingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'AI đang suy luận từ số liệu...',
                  style: TextStyle(color: Color(0xFFDDD6FE), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFFD97706)
                    : const Color(0xFF1E293B),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                msg.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}
