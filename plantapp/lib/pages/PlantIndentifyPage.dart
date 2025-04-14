import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plantapp/pages/micro/PlantHealthCareSuggestionCard.dart';
import 'package:plantapp/pages/micro/PlantSuggestionCard.dart';
import 'package:plantapp/pages/models/PlantHealthCareSuggestion.dart';
import 'package:plantapp/pages/models/PlantSuggestion.dart';
import '../services/PlantIndentifyService.dart';
import '../services/ImageEncoder.dart';

class PlantIdentifyPage extends StatefulWidget {
  const PlantIdentifyPage({super.key});

  @override
  _PlantIdentifyPageState createState() => _PlantIdentifyPageState();
}

class _PlantIdentifyPageState extends State<PlantIdentifyPage> {
  File? _imageFile;
  Uint8List? _imageBytes;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isHealthAssessment = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Tin nhắn chào mừng sinh động
    _messages.add({
      'type': 'bot',
      'text': 'Hãy gửi ảnh cây nào, mình sẵn sàng đây! 🌱',
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        if (kIsWeb) {
          pickedFile.readAsBytes().then((bytes) {
            setState(() {
              _imageFile = null;
              _imageBytes = bytes;
              _messages.add({
                'type': 'user_image',
                'image': bytes,
              });
            });
            _sendRequest(_isHealthAssessment
                ? "/health_assessment?language=en&details=local_name,description,url,treatment,classification,common_names,cause"
                : "/identification?details=common_names,url,description,taxonomy,synonyms,watering,best_light_condition,best_soil_type,common_uses,cultural_significance,toxicity,best_watering&language=en");
            _scrollToBottom();
          });
        } else {
          _imageFile = File(pickedFile.path);
          _imageBytes = null;
          _messages.add({
            'type': 'user_image',
            'image': _imageFile,
          });
          _sendRequest(_isHealthAssessment
              ? "/health_assessment?language=en&details=local_name,description,url,treatment,classification,common_names,cause"
              : "/identification?details=common_names,url,description,taxonomy,synonyms,watering,best_light_condition,best_soil_type,common_uses,cultural_significance,toxicity,best_watering&language=en");
          _scrollToBottom();
        }
      });
    }
  }

  Future<void> _sendRequest(String urlPath) async {
    setState(() {
      _isLoading = true;
      _messages.add({
        'type': 'bot',
        'text': 'Chờ mình xử lý một chút nhé...',
      });
    });

    final String base64Image;
    if (kIsWeb) {
      base64Image = base64Encode(_imageBytes!);
    } else {
      base64Image = await ImageEncoder.encodeImageToBase64(_imageFile!);
    }

    final response = await PlantIdentifyService.identifyPlant(base64Image, urlPath);

    setState(() {
      _isLoading = false;
      _messages.removeLast(); // Xóa tin nhắn "Chờ mình xử lý..."
    });

    if (response != null) {
      final Map<String, dynamic> data = json.decode(response);
      if (urlPath.contains("health_assessment")) {
        final List<dynamic> suggestions = data['result']['disease']['suggestions'];
        final healthCareSuggestions = suggestions
            .map((suggestion) => PlantHealthCareSuggestion.fromJson(suggestion))
            .toList();
        _messages.add({
          'type': 'bot',
          'text': 'Xong rồi! Đây là gợi ý chăm sóc sức khỏe cây nhé! 🌿',
        });
        _messages.add({
          'type': 'bot',
          'suggestions': healthCareSuggestions,
          'isHealthCare': true,
        });
      } else {
        final List<dynamic> suggestions = data['result']['classification']['suggestions'];
        final plantSuggestions = suggestions
            .map((suggestion) => PlantSuggestion.fromJson(suggestion))
            .toList();
        _messages.add({
          'type': 'bot',
          'text': 'Xong rồi! Đây là kết quả nhận diện cây nhé! 🌱',
        });
        _messages.add({
          'type': 'bot',
          'suggestions': plantSuggestions,
          'isHealthCare': false,
        });
      }
    } else {
      _messages.add({
        'type': 'bot',
        'text': 'Ôi, mình không nhận diện được cây này. Thử ảnh khác nhé! 😅',
      });
    }

    setState(() {});
    _scrollToBottom();
  }

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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Lỗi"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Plant ID Chatbot",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 25,
          ),
        ),
        backgroundColor: const Color.fromRGBO(161, 207, 107, 1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                if (message['type'] == 'user_image') {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: kIsWeb
                            ? Image.memory(
                          message['image'],
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                        )
                            : Image.file(
                          message['image'],
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                } else if (message['type'] == 'bot' && message['text'] != null) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(200, 230, 201, 1), // Xanh nhạt
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: const Color.fromRGBO(161, 207, 107, 1),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        message['text'],
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  );
                } else if (message['type'] == 'bot' && message['suggestions'] != null) {
                  final suggestions = message['suggestions'] as List<dynamic>;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(200, 230, 201, 1), // Xanh nhạt
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: const Color.fromRGBO(161, 207, 107, 1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message['isHealthCare']
                                ? "Gợi ý chăm sóc sức khỏe cây:"
                                : "Kết quả nhận diện cây:",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...suggestions.map((suggestion) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: message['isHealthCare']
                                  ? PlantHealthCareSuggestionCard(suggestion)
                                  : PlantSuggestionCard(suggestion),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  );
                }
                return Container();
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.photo_library,
                    color: Color.fromRGBO(74, 173, 82, 1),
                  ),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.camera_alt,
                    color: Color.fromRGBO(74, 173, 82, 1),
                  ),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isHealthAssessment = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isHealthAssessment
                        ? Colors.grey[300]
                        : Colors.blue, // Xanh dương cho Nhận diện cây
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  ),
                  child: Text(
                    "Nhận diện cây",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isHealthAssessment = true;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isHealthAssessment
                        ? const Color.fromRGBO(74, 173, 82, 1) // Xanh lá cây cho Sức khỏe cây
                        : Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  ),
                  child: Text(
                    "Sức khỏe cây",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (_isLoading) const CircularProgressIndicator(),
              ],
            ),
          ),
        ],

      ),
    );
  }
}