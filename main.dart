import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() => runApp(const FotoChudoApp());

const _violet = Color(0xFF7655E8);
const _ink = Color(0xFF17152A);
const _muted = Color(0xFF77748A);

class FotoChudoApp extends StatelessWidget {
  const FotoChudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ФотоЧудо',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _violet, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF8F7FC),
        fontFamily: 'Roboto',
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatMessage {
  ChatMessage({required this.text, required this.fromUser, this.image});
  final String text;
  final bool fromUser;
  final File? image;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  final _speech = stt.SpeechToText();
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Привет! Я ФотоЧудо ✨\n\nЗагрузи фотографию и расскажи, что хочешь изменить. Можно написать или надиктовать задачу.',
      fromUser: false,
    ),
  ];
  File? _selectedImage;
  bool _listening = false;
  bool _busy = false;

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (file != null && mounted) setState(() => _selectedImage = File(file.path));
  }

  Future<void> _takePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 92);
    if (file != null && mounted) setState(() => _selectedImage = File(file.path));
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!available) {
      _showNotice('Не удалось включить распознавание речи. Проверь разрешение на микрофон.');
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      localeId: 'ru_RU',
      onResult: (result) => setState(() => _controller.text = result.recognizedWords),
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty && _selectedImage == null) return;
    setState(() {
      _messages.add(ChatMessage(text: text.isEmpty ? 'Посмотри эту фотографию' : text,
          fromUser: true, image: _selectedImage));
      _controller.clear();
      _selectedImage = null;
      _busy = true;
    });
    // Demo response only. Real AI generation will be connected through a secure backend.
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _messages.add(ChatMessage(
          text: 'Задача принята! Сейчас это демонстрационный интерфейс: подключение генерации изображений, оплаты и серверной обработки — следующий этап разработки.',
          fromUser: false,
        ));
      });
    });
  }

  void _showNotice(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 18,
        title: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: _violet, borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white)),
          const SizedBox(width: 11),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ФотоЧудо', style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 18)),
            Text('Твоя магия фотографий', style: TextStyle(color: _muted, fontSize: 11)),
          ]),
        ]),
        actions: [
          IconButton(onPressed: () => _showNotice('История работ появится в следующей версии.'),
            icon: const Icon(Icons.history_rounded, color: _ink)),
          const SizedBox(width: 5),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            itemCount: _messages.length + (_busy ? 1 : 0),
            itemBuilder: (context, index) {
              if (_busy && index == _messages.length) return const _TypingBubble();
              return _MessageBubble(message: _messages[index]);
            },
          ),
        ),
        if (_selectedImage != null)
          Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(12),
                child: Image.file(_selectedImage!, width: 66, height: 66, fit: BoxFit.cover)),
              const SizedBox(width: 10),
              const Expanded(child: Text('Фото готово к отправке', style: TextStyle(fontWeight: FontWeight.w600))),
              IconButton(onPressed: () => setState(() => _selectedImage = null), icon: const Icon(Icons.close)),
            ])),
        _Composer(
          controller: _controller,
          listening: _listening,
          onGallery: _pickImage,
          onCamera: _takePhoto,
          onVoice: _toggleVoice,
          onSend: _send,
        ),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.fromUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: user ? _violet : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(19), topRight: const Radius.circular(19),
            bottomLeft: Radius.circular(user ? 19 : 5), bottomRight: Radius.circular(user ? 5 : 19)),
          boxShadow: [if (!user) BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (message.image != null) ...[
            ClipRRect(borderRadius: BorderRadius.circular(11),
              child: Image.file(message.image!, width: 250, fit: BoxFit.cover)),
            const SizedBox(height: 9),
          ],
          Text(message.text, style: TextStyle(color: user ? Colors.white : _ink, height: 1.35, fontSize: 14)),
        ]),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) => Align(alignment: Alignment.centerLeft,
    child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: _violet)),
        SizedBox(width: 9), Text('ФотоЧудо думает…', style: TextStyle(color: _muted, fontSize: 13)),
      ])));
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.listening, required this.onGallery,
    required this.onCamera, required this.onVoice, required this.onSend});
  final TextEditingController controller;
  final bool listening;
  final VoidCallback onGallery, onCamera, onVoice, onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFEDEBF3)))),
      child: Column(children: [
        Row(children: [
          _ToolButton(icon: Icons.photo_library_outlined, label: 'Галерея', onTap: onGallery),
          const SizedBox(width: 8),
          _ToolButton(icon: Icons.camera_alt_outlined, label: 'Камера', onTap: onCamera),
          const Spacer(),
          if (listening) const Text('Слушаю…', style: TextStyle(color: _violet, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 9),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: TextField(
            controller: controller,
            minLines: 1, maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Опиши, что сделать с фото…', hintStyle: const TextStyle(color: Color(0xFF9B98A8), fontSize: 13),
              filled: true, fillColor: const Color(0xFFF5F3FA), contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          )),
          const SizedBox(width: 7),
          _RoundButton(icon: listening ? Icons.stop_rounded : Icons.mic_none_rounded, onTap: onVoice, filled: false),
          const SizedBox(width: 6),
          _RoundButton(icon: Icons.arrow_upward_rounded, onTap: onSend, filled: true),
        ]),
      ]),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.label, required this.onTap});
  final IconData icon; final String label; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF5F3FA), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [Icon(icon, size: 17, color: _violet), const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: _ink, fontWeight: FontWeight.w600))])));
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, required this.filled});
  final IconData icon; final VoidCallback onTap; final bool filled;
  @override
  Widget build(BuildContext context) => Material(color: filled ? _violet : const Color(0xFFF0EDFA), shape: const CircleBorder(),
    child: InkWell(onTap: onTap, customBorder: const CircleBorder(), child: SizedBox(width: 44, height: 44,
      child: Icon(icon, color: filled ? Colors.white : _violet, size: 22))));
}
