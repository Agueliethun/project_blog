import 'package:flutter/material.dart';

void showErrorMessage(String message, BuildContext context) {
  showDialog(
      builder: ((context) => AlertDialog(
            content: Text(message),
          )),
      context: context);
}
