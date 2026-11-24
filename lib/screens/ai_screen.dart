
import 'package:flutter/material.dart';
import 'package:elora_school/widgets/elora_components.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/services/ai_service.dart';

class EloraAiPage extends StatefulWidget {
  const EloraAiPage({super.key});

  @override
  State<EloraAiPage> createState() => _EloraAiPageState();
}

class _EloraAiPageState extends State<EloraAiPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;

  final List<Map<String, dynamic>> messages = [
    {
      'message':
          'Hi! 👋\nAku ELORA AI, asisten informasi pendidikanmu. '
          'Ada yang bisa aku bantu hari ini?',
      'isUser': false,
    },
  ];

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    setState(() { messages.add({'message': text, 'isUser': true}); _isLoading = true; });
    _controller.clear();
    _scrollToBottom();
    final history = messages
        .where((item) => item['isUser'] is bool && item['message'] is String)
        .map<Map<String, String>>((item) => {
          'role': item['isUser'] == true ? 'user' : 'assistant',
          'content': item['message'].toString(),
        }).toList();
    try {
      final reply = await AiService.instance.sendMessage(history);
      if (!mounted) return;
      setState(() => messages.add({'message': reply, 'isUser': false}));
    } catch (e) {
      if (!mounted) return;
      setState(() => messages.add({
        'message': 'Terjadi kesalahan saat menghubungi ELORA AI: ${e.toString().replaceFirst('Exception: ', '')}',
        'isUser': false,
      }));
    } finally {
      if (mounted) { setState(() => _isLoading = false); _scrollToBottom(); }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eloraBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildChat()),
            if (_isLoading) _buildTypingIndicator(),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: eloraPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: eloraPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ELORA AI',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: eloraDark,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Your student assistant',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          const EloraStatusBadge(
            label: 'AI Assistant',
            color: eloraPrimary,
            backgroundColor: Color(0xFFE5F1F0),
            fontSize: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildChat() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final bool isUser = message['isUser'] == true;

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: EloraCard(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              color: isUser ? eloraPrimary : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: Border.all(
                color: isUser ? eloraPrimary : Colors.grey.shade200,
              ),
              child: isUser
                ? Text(
                    message['message'].toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.white,
                    ),
                  )
                : MarkdownBody(
                    data: message['message'].toString(),
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: eloraDark,
                      ),
                      strong: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: eloraDark,
                      ),
                      h1: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: eloraDark,
                      ),
                      h2: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: eloraDark,
                      ),
                      h3: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: eloraDark,
                      ),
                      listBullet: const TextStyle(
                        fontSize: 14,
                        color: eloraPrimary,
                      ),
                      blockSpacing: 10,
                      listIndent: 20,
                      h1Padding: const EdgeInsets.only(bottom: 6),
                      h2Padding: const EdgeInsets.only(bottom: 4),
                    ),
                  ),
                ),
              ),
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: eloraPrimary,
                  ),
                ),
                SizedBox(width: 9),
                Text(
                  'ELORA AI sedang menjawab...',
                  style: TextStyle(fontSize: 11, color: eloraDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Expanded(
            child: EloraTextField(
              controller: _controller,
              enabled: !_isLoading,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Ask ELORA AI...',
                hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                filled: true,
                fillColor: eloraBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Material(
            color: _isLoading ? Colors.grey : eloraPrimary,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _isLoading ? null : _sendMessage,
              child: SizedBox(
                width: 45,
                height: 45,
                child: Icon(
                  _isLoading ? Icons.hourglass_top : Icons.send_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
