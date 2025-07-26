import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AssistantBotScreen extends StatefulWidget {
  final String apiKey;
  const AssistantBotScreen({super.key, required this.apiKey});

  @override
  State<AssistantBotScreen> createState() => _AssistantBotScreenState();
}

class _AssistantBotScreenState extends State<AssistantBotScreen>
    with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final List<_ChatMessage> _messages = [];
  late AnimationController _fadeController;
  late AnimationController _thinkingPulseController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _thinkingPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.6,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _fadeController.dispose();
    _thinkingPulseController.dispose();
    super.dispose();
  }

  Future<void> _sendQuery() async {
    final query = _inputController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: query, sender: Sender.user));
      _messages.add(
        _ChatMessage(text: 'Thinking...', sender: Sender.bot, isThinking: true),
      );
    });

    _inputController.clear();

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${widget.apiKey}',
    );

    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": query},
          ],
        },
      ],
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final text =
            decoded['candidates']?[0]['content']['parts'][0]['text'] ??
            "No response found.";

        setState(() {
          // Remove "Thinking..."
          _messages.removeWhere((msg) => msg.isThinking);
          _messages.add(
            _ChatMessage(text: _formatResponse(text), sender: Sender.bot),
          );
        });
      } else {
        setState(() {
          _messages.removeWhere((msg) => msg.isThinking);
          _messages.add(
            _ChatMessage(
              text: "Error: ${response.statusCode}\n${response.body}",
              sender: Sender.bot,
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        _messages.removeWhere((msg) => msg.isThinking);
        _messages.add(
          _ChatMessage(text: "Failed to connect: $e", sender: Sender.bot),
        );
      });
    }
  }

  String _formatResponse(String response) {
    return response
        .replaceAll('*****', '')
        .replaceAllMapped(
          RegExp(r'\*\*(.*?)\*\*'),
          (match) => '<b>${match[1]}</b>',
        )
        .trim();
  }

  Widget _buildMessage(_ChatMessage message) {
    final isUser = message.sender == Sender.user;
    final alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bubbleColor = isUser ? Colors.blue[400] : Colors.grey[200];
    final textColor = isUser ? Colors.white : Colors.black87;
    final text = message.text;

    Widget formattedText;

    if (text.contains('<b>')) {
      final spans = <TextSpan>[];
      final parts = text.split(RegExp(r'(<b>.*?<\/b>)'));
      for (var part in parts) {
        if (part.startsWith('<b>') && part.endsWith('</b>')) {
          spans.add(
            TextSpan(
              text: part.replaceAll(RegExp(r'<\/?b>'), ''),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        } else {
          spans.add(TextSpan(text: part));
        }
      }
      formattedText = RichText(
        text: TextSpan(
          style: TextStyle(color: textColor, fontSize: 16),
          children: spans,
        ),
      );
    } else if (text.contains('- ') || text.contains('* ')) {
      final lines = text.split('\n');
      final bullets = lines.where((line) => line.trim().isNotEmpty).map((line) {
        String clean = line.replaceAll(RegExp(r'^[\*\-] '), '').trim();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '• ',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: Text(
                clean,
                style: TextStyle(fontSize: 16, height: 1.5, color: textColor),
              ),
            ),
          ],
        );
      }).toList();
      formattedText = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: bullets,
      );
    } else {
      formattedText = Text(
        text,
        style: TextStyle(color: textColor, fontSize: 16),
      );
    }

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: isUser
              ? const Radius.circular(14)
              : const Radius.circular(0),
          bottomRight: isUser
              ? const Radius.circular(0)
              : const Radius.circular(14),
        ),
      ),
      child: formattedText,
    );

    // If this message is "Thinking..." apply pulsing animation
    if (message.isThinking) {
      return ScaleTransition(
        scale: _thinkingPulseController,
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: bubble,
        ),
      );
    }

    // Otherwise, fade in animation for new bot messages
    if (!isUser) {
      return FadeTransition(
        opacity: _fadeController,
        child: Align(alignment: Alignment.centerLeft, child: bubble),
      );
    }

    // User messages show normally
    return Align(alignment: Alignment.centerRight, child: bubble);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  // Trigger fade animation for last bot message
                  if (index == _messages.length - 1 &&
                      _messages[index].sender == Sender.bot &&
                      !_messages[index].isThinking) {
                    _fadeController.forward(from: 0);
                  }
                  return _buildMessage(_messages[index]);
                },
              ),
            ),
            const Divider(height: 1),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      enabled: !_messages.any((m) => m.isThinking),
                      onSubmitted: (_) {
                        if (!_messages.any((m) => m.isThinking)) _sendQuery();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _messages.any((m) => m.isThinking)
                        ? null
                        : _sendQuery,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _messages.any((m) => m.isThinking)
                            ? Colors.grey
                            : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum Sender { user, bot }

class _ChatMessage {
  final String text;
  final Sender sender;
  final bool isThinking;
  _ChatMessage({
    required this.text,
    required this.sender,
    this.isThinking = false,
  });
}
