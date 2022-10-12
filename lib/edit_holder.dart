import 'package:development_blog/post.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'main.dart';

typedef BoolCallback = bool Function();

class EditHolder extends StatefulWidget {
  final Widget display;
  final Widget edit;
  final VoidCallback editFunc;
  final VoidCallback deleteFunc;
  final VoidCallback saveFunc;
  final BoolCallback canEditFunc;
  final int? contentIndex;

  const EditHolder(
      {super.key,
      required this.display,
      required this.edit,
      required this.editFunc,
      required this.deleteFunc,
      required this.canEditFunc,
      required this.saveFunc,
      this.contentIndex});

  @override
  State<StatefulWidget> createState() {
    return _EditHolderState();
  }
}

class _EditHolderState extends State<EditHolder> {
  bool editing = false;

  @override
  Widget build(BuildContext context) {
    if (widget.canEditFunc()) {
      if (editing) {
        return StandardPadding(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.edit,
            Center(
                child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle),
                  onPressed: () {
                    widget.saveFunc.call();
                    setState(() {
                      editing = false;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel),
                  onPressed: () {
                    widget.deleteFunc.call();
                    setState(() {
                      editing = false;
                    });
                  },
                ),
              ],
            )),
          ],
        ));
      } else {
        return StandardPadding(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.display,
            Center(
                child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    widget.editFunc.call();
                    setState(() {
                      editing = true;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel),
                  onPressed: () {
                    widget.deleteFunc.call();
                    setState(() {
                      editing = false;
                    });
                  },
                ),
                if (widget.contentIndex != null)
                  AddContentPanel(contentIndex: widget.contentIndex!),
              ],
            )),
          ],
        ));
      }
    } else {
      return StandardPadding(
        child: widget.display,
      );
    }
  }
}

class StandardPadding extends StatelessWidget {
  final Widget child;

  const StandardPadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 25.0),
        child: child);
  }
}

class AddContentPanel extends StatelessWidget {
  final int contentIndex;

  const AddContentPanel({super.key, required this.contentIndex});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.abc),
          onPressed: () {
            Provider.of<BlogModel>(context, listen: false).addContent(
                TextContent(contentIndex: contentIndex + 1, text: ""),
                contentIndex + 1);
          },
        ),
        IconButton(
          icon: const Icon(Icons.image),
          onPressed: () {
            Provider.of<BlogModel>(context, listen: false).addContent(
                ImageContent(
                  contentIndex: contentIndex + 1,
                  url: "",
                ),
                contentIndex + 1);
          },
        ),
      ],
    ));
  }
}
