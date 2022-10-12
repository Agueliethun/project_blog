import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'edit_holder.dart';
import 'login.dart';
import 'main.dart';

class CommentArea extends StatelessWidget {
  const CommentArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BlogModel>(
        builder: (context, blogModel, child) => Consumer<LoginInfo>(
            builder: (context, loginInfo, child) => Column(
                  children: [
                    ...blogModel.selectedPost.comments
                        .where((element) => element.parentId == ""),
                    const Divider(),
                    const CommentEditWidget(parentCommentId: "none"),
                  ],
                )));
  }
}

class Comment extends StatelessWidget {
  final String commentId;
  final String authorId;
  final List<String> content;
  final String parentId;

  const Comment({
    super.key,
    required this.commentId,
    required this.authorId,
    required this.parentId,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...content.map((paragraph) => Text(paragraph)).toList(),
                  const Divider(),
                  Consumer<BlogModel>(
                      builder: ((context, blogModel, child) =>
                          Column(children: [
                            Row(children: [
                              blogModel.users[authorId]?.icon,
                              Expanded(
                                  child: Text(blogModel.users[authorId]?.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall)),
                            ]),
                            CommentEditWidget(parentCommentId: commentId),
                            if (blogModel.commentRelations
                                .containsKey(commentId))
                              Padding(
                                padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                                child: Column(
                                    children:
                                        blogModel.commentRelations[commentId]),
                              )
                          ])))
                ])));
  }
}

class CommentEditWidget extends StatefulWidget {
  final String parentCommentId;

  const CommentEditWidget({super.key, required this.parentCommentId});

  @override
  State<CommentEditWidget> createState() {
    return _CommentEditWidget();
  }
}

class _CommentEditWidget extends State<CommentEditWidget> {
  final TextEditingController editController = TextEditingController();

  bool canEdit(LoginInfo loginInfo, BlogModel model) {
    return loginInfo.loggedIn &&
        !model.selectedPost.newPost &&
        loginInfo.userId != null &&
        loginInfo.userId != "";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LoginInfo>(
        builder: ((context, loginInfo, child) => Consumer<BlogModel>(
            builder: ((context, model, child) => Column(children: [
                  Align(
                      alignment: Alignment.centerLeft,
                      child: EditHolder(
                        display: Text(
                          editController.text,
                          textAlign: TextAlign.start,
                        ),
                        edit: TextField(
                          controller: editController,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          showCursor: true,
                          maxLength: 500,
                        ),
                        editFunc: () {},
                        deleteFunc: () {
                          setState(() {
                            editController.text = "";
                          });
                        },
                        saveFunc: () {
                          setState(() {});
                        },
                        canEditFunc: () => canEdit(loginInfo, model),
                      )),
                  if (canEdit(loginInfo, model) && editController.text != "")
                    IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: () {
                        if (editController.text != "" &&
                            loginInfo.userId != null) {
                          (model.addComment(editController.text,
                                  widget.parentCommentId, loginInfo.userId!))
                              .then((success) {
                            if (success) editController.text = "";
                            setState(() {});
                          });
                        }
                      },
                    ),
                ])))));
  }

  @override
  void dispose() {
    editController.dispose();
    super.dispose();
  }
}
