import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';

import 'comments.dart';
import 'edit_holder.dart';
import 'login.dart';
import 'pocket_base.dart';
import 'post.dart';

void main() {
  runApp(
    MultiProvider(providers: [
      ChangeNotifierProvider(
        create: (context) => BlogModel(),
      ),
      ChangeNotifierProvider(
        create: (context) => LoginInfo(),
      ),
    ], child: const DevBlog()),
  );
}

class User {
  final Widget icon;
  final String name;

  const User(this.icon, this.name);
}

class BlogModel extends ChangeNotifier {
  final Map<String, User> _users = {};
  UnmodifiableMapView get users => UnmodifiableMapView(_users);

  final List<Post> _posts = [];
  UnmodifiableListView get posts => UnmodifiableListView(_posts);

  final Map<String, Comment> _commentIds = {};
  UnmodifiableMapView get commentIds => UnmodifiableMapView(_commentIds);

  final Map<String, List<Comment>> _commentRelations = {};
  UnmodifiableMapView get commentRelations =>
      UnmodifiableMapView(_commentRelations);

  static Post initialPost = Post(
      "Select a Post",
      [
        const TextContent(
            contentIndex: 0,
            text: "Select a post from the menu at the side (slide on mobile)")
      ],
      [],
      [],
      false,
      "");

  Post selectedPost = initialPost;

  Future<List<Post>> getPosts() async {
    final authToken = client.authStore.token;
    final authModel = client.authStore.model;

    await client.admins.authViaEmail("murnkamp@gmail.com", "Serendethur98");

    List<Post> retList = [];

    _commentIds.clear();
    _commentRelations.clear();

    final results = await client.records.getList(
      "posts",
      sort: "-created",
    );

    for (RecordModel record in results.items) {
      List<String> tags = [];

      List<Content> content = [];
      ResultList<RecordModel> contentRecords = await client.records.getList(
          "content",
          filter: "postId = '${record.id}'",
          sort: "-order");

      int index = 0;
      for (RecordModel contentRecord in contentRecords.items) {
        String text = contentRecord.getStringValue("text");
        if (text != "") {
          content.add(TextContent(contentIndex: index++, text: text));
        } else {
          var uri = client.records
              .getFileUrl(contentRecord, contentRecord.getStringValue("image"));
          content.add(ImageContent(contentIndex: index++, url: uri.toString()));
        }
      }

      List<Comment> comments = [];
      ResultList<RecordModel> commentRecords = await client.records.getList(
          "comments",
          filter: "postId = '${record.id}'",
          sort: "-created");

      for (RecordModel contentRecord in commentRecords.items) {
        String parentId = contentRecord.getStringValue("commentId");

        String commentId = contentRecord.id;
        String content = contentRecord.getStringValue("content");
        String userId = contentRecord.getStringValue("author");
        Comment comment = Comment(
            commentId: commentId,
            authorId: userId,
            content: content.split('\\n'),
            parentId: parentId);
        comments.add(comment);

        if (parentId != "") {
          _commentRelations.putIfAbsent(parentId, () => []).add(comment);
        }

        if (!_users.containsKey(userId)) {
          UserModel userModel = await client.users.getOne(userId);

          var avatar = userModel.profile!.getListValue<String>("avatar");
          var url = client.records.getFileUrl(userModel.profile!, avatar[0]);

          String name = userModel.profile!.getStringValue("name");

          User user = User(
              Image.network(
                url.toString(),
                width: 30,
                height: 30,
                errorBuilder: ((context, error, stackTrace) =>
                    const Icon(Icons.account_circle)),
              ),
              name);
          _users[userId] = user;
        }
      }

      client.authStore.clear();
      client.authStore.save(authToken, authModel);

      retList.add(Post(record.getStringValue("title"), content, tags, comments,
          false, record.id));
    }

    _posts.clear();
    _posts.addAll(retList);

    notifyListeners();

    // Timer.periodic(const Duration(minutes: 30), (timer) {
    //   getPosts();
    // });

    return retList;
  }

  void selectPost(Post post) {
    selectedPost = post;

    notifyListeners();
  }

  void resetPost() {
    selectPost(initialPost);
    notifyListeners();
  }

  void newPost(String title) {
    var post = Post(title, [], [], [], true, "");
    _posts.add(post);
    selectPost(post);
    notifyListeners();
  }

  void removeContent(Content widget) {
    selectedPost.contents.remove(widget);
    fixContentIDs();
    notifyListeners();
  }

  void updateContent(Content oldContent, Content newContent) {
    int index = selectedPost.contents.indexOf(oldContent);
    if (index == -1) {
      addContent(newContent, -1);
      return;
    }
    selectedPost.contents.replaceRange(index, index + 1, [newContent]);
    fixContentIDs();
    notifyListeners();
  }

  void addContent(Content content, int index) {
    if (index == -1) {
      selectedPost.contents.add(content);
    } else {
      selectedPost.contents.insert(index, content);
    }
    fixContentIDs();
    notifyListeners();
  }

  void fixContentIDs() {
    List<Content> contentList = [];

    int index = 0;
    for (Content content in selectedPost.contents) {
      contentList.add(content.copy(index++));
    }

    selectedPost.contents.clear();
    selectedPost.contents.addAll(contentList);
  }

  Future<bool> uploadNewPost() {
    fixContentIDs();

    if (selectedPost.newPost) {
      client.records.create("posts", body: {"title": selectedPost.title}).then(
          (value) {
        selectedPost.id = value.id;
        List<Future<bool>> futures = [];
        for (Content content in selectedPost.contents) {
          String id = value.id;
          futures.add(content.createRecord(client, id));
        }
        for (var f in futures) {
          f.then((completed) {
            if (!completed) {
              return false;
            }
          });
        }

        selectedPost.newPost = false;

        notifyListeners();

        return true;
      }, onError: (value) {
        return false;
      });
    }

    return Future.value(false);
  }

  Future<bool> addComment(String text, String parentCommentId, String userId) {
    var body = {
      "author": userId,
      "content": text,
      "postId": selectedPost.id,
    };
    if (parentCommentId != "none") {
      body["commentId"] = parentCommentId;
    }

    client.records.create("comments", body: body).then((record) {
      return true;
    }, onError: (value) {
      return false;
    });

    getPosts();
    return Future.value(true);
  }
}

class DevBlog extends StatefulWidget {
  const DevBlog({super.key});

  @override
  State<DevBlog> createState() => _DevBlogState();
}

class _DevBlogState extends State<DevBlog> {
  bool isLoaded = false;

  @override
  void initState() {
    super.initState();

    Provider.of<BlogModel>(context, listen: false)
        .getPosts()
        .whenComplete(() => isLoaded = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Development Blog',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFE23518),
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(titleTextStyle: TextStyle(fontSize: 45)),
      ),
      home: Scaffold(
        body: Row(
          children: const [
            Expanded(child: PostSelect()),
            Expanded(
              flex: 6,
              child: Center(
                child: Padding(
                    padding: EdgeInsets.all(15.0), child: DisplayArea()),
              ),
            )
          ],
        ),
        appBar: AppBar(
          title: Text('Development Blog',
              style: Theme.of(context).appBarTheme.titleTextStyle),
          toolbarHeight: 75,
          actions: const [
            Padding(
                padding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 15.0),
                child: LoginButton())
          ],
        ),
      ),
    );
  }
}

class PostSelect extends StatelessWidget {
  const PostSelect({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BlogModel>(
      builder: (context, model, child) => ListView(children: [
        Column(
          children: [
            ...model.posts
                .map((post) => Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: TextButton(
                        onPressed: () {
                          if (model.posts.contains(model.selectedPost) ||
                              !model.selectedPost.newPost) {
                            model.selectPost(post);
                          }
                        },
                        style: (post == model.selectedPost)
                            ? TextButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).highlightColor)
                            : Theme.of(context).textButtonTheme.style,
                        child: Text(post.title))))
                .toList(),
            Consumer<LoginInfo>(
              builder: (context, loginInfo, child) {
                if (loginInfo.admin) {
                  return const NewPostSelect();
                } else {
                  return const Divider();
                }
              },
            )
          ],
        )
      ]),
    );
  }
}

class NewPostSelect extends StatefulWidget {
  const NewPostSelect({super.key});

  @override
  State<NewPostSelect> createState() {
    return _NewPostSelectState();
  }
}

class _NewPostSelectState extends State<NewPostSelect> {
  bool editing = false;
  final titleEditingController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    if (!editing) {
      return TextButton(
        child: const Text("New Post"),
        onPressed: () => setState(() {
          editing = true;
          titleEditingController.text = "";
          Provider.of<BlogModel>(context, listen: false)
              .selectPost(Post("", [], [], [], true, ""));
        }),
      );
    } else {
      return Row(
        children: [
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: TextField(
                    controller: titleEditingController,
                    autocorrect: true,
                    enableSuggestions: false,
                  ))),
          IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: () => setState(() {
              editing = false;
              titleEditingController.text = "";
              Provider.of<BlogModel>(context, listen: false).resetPost();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle),
            onPressed: () => setState(() {
              editing = false;
              Provider.of<BlogModel>(context, listen: false)
                  .newPost(titleEditingController.text);
              titleEditingController.text = "";
            }),
          )
        ],
      );
    }
  }
}

class DisplayArea extends StatelessWidget {
  const DisplayArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BlogModel>(
      builder: ((context, model, child) {
        if (!model.selectedPost.newPost) {
          return ListView(children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                    child: Padding(
                        padding: const EdgeInsets.all(25),
                        child: Text(
                          model.selectedPost.title,
                          style: Theme.of(context).textTheme.headline2,
                        ))),
                ...model.selectedPost.contents
              ],
            ),
            const CommentArea(),
          ]);
        } else {
          return const PostEditArea();
        }
      }),
    );
  }
}

class PostEditArea extends StatelessWidget {
  const PostEditArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BlogModel>(
        builder: (context, model, child) => ListView(children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                      child: Padding(
                          padding: const EdgeInsets.all(25),
                          child: Text(
                            model.selectedPost.title,
                            style: Theme.of(context).textTheme.headline2,
                          ))),
                  ...model.selectedPost.contents,
                  AddContentPanel(
                      contentIndex: model.selectedPost.contents.length - 1),
                  TextButton(
                    child: const Text("Upload"),
                    onPressed: () {
                      model.uploadNewPost();
                    },
                  )
                ],
              ),
            ]));
  }
}
