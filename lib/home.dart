import 'dart:io';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/consts.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:image_picker/image_picker.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Gemini gemini = Gemini.instance;
  List<ChatMessage> messages = [];

  ChatUser currentUser = ChatUser(id: "0", firstName: "user");
  ChatUser geminiUser = ChatUser(id: "1", firstName: "Gemini");

  // late GenerativeModel model; // Declare the model

  // @override
  // void initState() {
  //   super.initState();
  //   // Initialize the model in initState
  //   model = GenerativeModel(
  //     model: 'gemini-1.5-pro-exp-0827',
  //     apiKey: GEMINI_API_KEY, // Replace with your API key
  //     // safetySettings: Adjust safety settings
  //     // See https://ai.google.dev/gemini-api/docs/safety-settings
  //     generationConfig: GenerationConfig(
  //       temperature: 2,
  //       topK: 64,
  //       topP: 0.95,
  //       maxOutputTokens: 8192,
  //       responseMimeType: 'text/plain',
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Gemini Chat",
        ),
      ),
      body: _buildUI(),
    );
  }

  Widget _buildUI() {
    return DashChat(
      inputOptions: InputOptions(trailing: [
        IconButton(
            onPressed: () => _pickImageSource(),
            icon: Icon(
              Icons.image,
            ))
      ]),
      currentUser: currentUser,
      onSend: _sendMessage,
      messages: messages,
    );
  }

  void _pickImageSource() {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                    leading: Icon(Icons.photo_library),
                    title: Text('Gallery'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _sendMediaMessage(ImageSource.gallery);
                    }),
                ListTile(
                  leading: Icon(Icons.photo_camera),
                  title: Text('Camera'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _sendMediaMessage(ImageSource.camera);
                  },
                ),
              ],
            ),
          );
        });
  }

  void _sendMessage(ChatMessage chatMessage) {
    setState(() {
      messages = [chatMessage, ...messages];
    });

    try {
      String question = chatMessage.text;
      List<Uint8List>? images;
      if (chatMessage.medias?.isNotEmpty ?? false) {
        images = [File(chatMessage.medias!.first.url).readAsBytesSync()];
      }

      // Only send to Gemini if there's an image
      if (images != null && images.isNotEmpty) {
        gemini
            .streamGenerateContent(
          question,
          images: images,
        )
            .listen((event) {
          ChatMessage? lastMessage = messages.firstOrNull;
          if (lastMessage != null && lastMessage.user == geminiUser) {
            lastMessage = messages.removeAt(0);

            String response = event.content?.parts?.fold(
                    "", (previous, current) => "$previous${current.text}") ??
                "";

            lastMessage.text += response;

            setState(
              () {
                messages = [lastMessage!, ...messages];
              },
            );
          } else {
            String response = event.content?.parts?.fold(
                    "", (previous, current) => "$previous ${current.text}") ??
                "";

            ChatMessage message = ChatMessage(
              user: geminiUser,
              createdAt: DateTime.now(),
              text: response,
            );
            setState(() {
              messages = [message, ...messages];
            });
          }
        });
      }
    } catch (e) {
      print(e);
    }
  }

  void _sendMediaMessage(ImageSource source) async {
    ImagePicker picker = ImagePicker();
    XFile? file = await picker.pickImage(
      source: source,
    );

    if (file != null) {
      ChatMessage chatMessage = ChatMessage(
        user: currentUser,
        createdAt: DateTime.now(),
        text:
            "Get the name of the medicine, its symptoms, primary diagnosis, usage, and dosage from the input image in the following format. \n" +
            "Example: ● Name\n" +
            "● Symptoms: \n and so on." +
            "Make sure to ask the person to visit the doctor if the problem persists.",
        medias: [
          ChatMedia(
            url: file.path,
            fileName: "",
            type: MediaType.image,
          )
        ],
      );
      _sendMessage(chatMessage); 
    }
  }
}
