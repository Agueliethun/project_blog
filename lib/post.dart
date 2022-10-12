import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';

import 'package:file_picker/file_picker.dart';

import 'comments.dart';
import 'edit_holder.dart';
import 'main.dart';

class Post {
  final String title;
  final List<Content> contents;
  final List<String> tags;
  final List<Comment> comments;

  bool newPost;
  String? id;

  Post(this.title, this.contents, this.tags, this.comments, this.newPost,
      this.id);
}

abstract class Content extends StatefulWidget {
  final int contentIndex;

  const Content({super.key, required this.contentIndex});

  Content copy(int newIndex);
  Future<bool> createRecord(PocketBase client, String postId);
}

class TextContent extends Content {
  const TextContent(
      {super.key, required super.contentIndex, required this.text});

  final String text;

  @override
  Content copy(int newIndex) {
    return TextContent(
      contentIndex: newIndex,
      text: text,
    );
  }

  @override
  State<StatefulWidget> createState() {
    return _TextContentState();
  }

  @override
  Future<bool> createRecord(PocketBase client, String postId) {
    try {
      client.records.create("content", body: {
        'postId': postId,
        'order': contentIndex + 1,
        'text': text
      }).then((value) => true);
    } catch (e) {
      return Future.value(false);
    }
    return Future.value(false);
  }
}

class _TextContentState extends State<TextContent> {
  final TextEditingController editController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Consumer<BlogModel>(builder: ((context, model, child) {
      return EditHolder(
        display: Text(widget.text),
        edit: TextField(
          controller: editController,
          keyboardType: TextInputType.multiline,
          maxLines: null,
          showCursor: true,
          maxLength: 500,
        ),
        editFunc: () {
          editController.text = widget.text;
        },
        deleteFunc: () {
          Provider.of<BlogModel>(context, listen: false).removeContent(widget);
        },
        saveFunc: () {
          Provider.of<BlogModel>(context, listen: false).updateContent(
              widget,
              TextContent(
                  contentIndex: widget.contentIndex,
                  text: editController.text));
        },
        canEditFunc: () => model.selectedPost.newPost,
        contentIndex: widget.contentIndex,
      );
    }));
  }

  @override
  void dispose() {
    editController.dispose();
    super.dispose();
  }
}

class ImageContent extends Content {
  const ImageContent(
      {super.key, required super.contentIndex, this.image, required this.url});

  final File? image;
  final String url;

  @override
  Content copy(int newIndex) {
    return ImageContent(
      contentIndex: newIndex,
      url: url,
    );
  }

  @override
  State<StatefulWidget> createState() {
    return _ImageContentState();
  }

  @override
  Future<bool> createRecord(PocketBase client, String postId) {
    try {
      if (image != null) {
        image!.readAsBytes().then((bytes) {
          Stream<List<int>> imageData = Stream.value(List<int>.from(bytes));
          imageData.length.then((length) {
            client.records.create("content", body: {
              'postId': postId,
              'order': contentIndex + 1,
            }, files: [
              MultipartFile("image", imageData, length)
            ]).then((value) => true);
          });
        });
      }
    } catch (e) {
      return Future.value(false);
    }
    return Future.value(false);
  }
}

class _ImageContentState extends State<ImageContent> {
  String url = "";
  File? imageFile;

  Future<void> edit() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        allowedExtensions: [".png", ".bmp", ".gif"],
        withData: true);

    if (result != null) {
      setState(() {
        imageFile = File(result.files.single.path!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BlogModel>(builder: ((context, model, child) {
      return EditHolder(
        display: Image.network(
          widget.url,
          errorBuilder: (context, error, stackTrace) {
            if (imageFile != null) {
              return Image.file(imageFile!);
            } else {
              return const Icon(Icons.image);
            }
          },
        ),
        edit: Image.network(
          widget.url,
          errorBuilder: (context, error, stackTrace) {
            if (imageFile != null) {
              return Image.file(imageFile!);
            } else {
              return const Icon(Icons.image);
            }
          },
        ),
        editFunc: () {
          edit();
        },
        deleteFunc: () {
          Provider.of<BlogModel>(context, listen: false).removeContent(widget);
        },
        saveFunc: () {
          Provider.of<BlogModel>(context, listen: false).updateContent(
              widget,
              ImageContent(
                  contentIndex: widget.contentIndex,
                  image: imageFile,
                  url: url));
        },
        canEditFunc: () => model.selectedPost.newPost,
        contentIndex: widget.contentIndex,
      );
    }));
  }
}
