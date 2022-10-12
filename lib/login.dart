import 'package:development_blog/util.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';

import 'pocket_base.dart';

class LoginInfo extends ChangeNotifier {
  static Icon logInIcon = const Icon(
    Icons.account_circle,
    size: 30.0,
    color: Color(0xFFE23518),
  );

  bool loggedIn = false;
  Widget avatar = logInIcon;
  bool admin = false;
  String? userId;
  late String email;
  late String name;

  Future<bool> login(
    String email,
    String password,
    BuildContext context,
  ) async {
    if (email == "" || password == "") {
      showDialog(
          builder: ((context) => const AlertDialog(
                content: Center(
                    child: Text("Email and password must not be empty.")),
              )),
          context: context);
      return false;
    }

    try {
      if (email == "murnkamp@gmail.com") {
        await client.admins.authViaEmail(email, password);

        name = "Matthew";
        admin = true;
      } else {
        UserAuth userAuth = await client.users.authViaEmail(email, password);
        name = userAuth.user!.profile!.getStringValue("name");

        userId = userAuth.user!.id;
        UserModel userModel = await client.users.getOne(userId!);

        var avatar = userModel.profile!.getListValue<String>("avatar");
        var url = client.records.getFileUrl(userModel.profile!, avatar[0]);

        this.avatar = Image.network(
          url.toString(),
          width: 30,
          height: 30,
        );
      }
    } catch (exception) {
      showErrorMessage("Unable to login - please check credentials.", context);
      return false;
    }

    this.email = email;
    loggedIn = true;
    notifyListeners();

    return true;
  }

  Future<bool> createAccount(String email, String password, String name,
      bool update, BuildContext context) async {
    try {
      if (email == "" || password == "" || name == "") {
        showErrorMessage(
            "A name must be entered to create a new account.", context);
        return false;
      }

      if (RegExp(r'\w+@\w+\.\w+').allMatches(email).length != 1) {
        showErrorMessage("Email is invalid.", context);
        return false;
      }

      if (password.length < 8) {
        showErrorMessage(
            "Password must be at least 8 characters long.", context);
        return false;
      }

      final user = await client.users.create(body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
      });

      await client.users.authViaEmail(email, password);
      userId = user.profile!.id;
      this.email = email;
      this.name = name;
      loggedIn = true;

      await client.records.update('profiles', user.profile!.id, body: {
        'name': name,
        'updates': update,
      });
    } catch (exception) {
      showDialog(
          builder: ((context) => AlertDialog(
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("OK"),
                  )
                ],
                content: const Text(
                    "Unable to create account. Please check that the provided email and password are valid."),
              )),
          context: context);
      return false;
    }

    notifyListeners();

    return true;
  }

  Future<void> logout() async {
    loggedIn = false;
    admin = false;
    name = "";
    email = "";
    avatar = logInIcon;
    client.authStore.clear();

    notifyListeners();
  }
}

class LoginButton extends StatelessWidget {
  const LoginButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LoginInfo>(builder: (context, loginInfo, child) {
      if (!loginInfo.loggedIn) {
        return IconButton(
            onPressed: () {
              showDialog(
                  context: context, builder: (context) => const LogInMenu());
            },
            icon: const Icon(Icons.account_circle, size: 30.0));
      } else {
        return IconButton(
            onPressed: () {
              showDialog(
                  context: context, builder: (context) => const LoggedInMenu());
            },
            icon: loginInfo.avatar);
      }
    });
  }
}

class LogInMenu extends StatefulWidget {
  const LogInMenu({super.key});

  @override
  State<LogInMenu> createState() => _LogInMenuState();
}

class _LogInMenuState extends State<LogInMenu> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  bool updates = false;
  bool newAccount = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: const Text("Log In"),
        contentPadding: const EdgeInsets.all(5.0),
        content: SizedBox(
            width: double.minPositive,
            child: ListView(children: [
              FormTextInput(controller: emailController, description: "Email"),
              FormTextInput(
                  controller: passwordController,
                  description: "Password",
                  password: true),
              const Divider(),
              Switch(
                  value: newAccount,
                  onChanged: (newVal) {
                    setState(() {
                      newAccount = newVal;
                    });
                  }),
              const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Center(
                    child: Text("Register"),
                  )),
              if (newAccount)
                Column(
                  children: [
                    FormTextInput(
                        controller: nameController,
                        description: "Account Name"),
                    Switch(
                        value: updates,
                        onChanged: (newVal) {
                          setState(() {
                            updates = newVal;
                          });
                        }),
                    const Text("Receive email updates?"),
                  ],
                )
            ])),
        actions: [
          Consumer<LoginInfo>(
            builder: (context, loginInfo, child) => TextButton(
                onPressed: () {
                  loginInfo
                      .createAccount(
                          emailController.text,
                          passwordController.text,
                          nameController.text,
                          updates,
                          context)
                      .then((success) => {
                            if (success) {Navigator.pop(context, true)}
                          });
                },
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).hintColor),
                child: const Text("Create Account")),
          ),
          Consumer<LoginInfo>(
            builder: (context, loginInfo, child) => TextButton(
              onPressed: () {
                loginInfo
                    .login(
                        emailController.text, passwordController.text, context)
                    .then((success) => {
                          if (success) {Navigator.pop(context, true)}
                        });
              },
              child: const Text("Log In"),
            ),
          ),
        ]);
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }
}

class FormTextInput extends StatelessWidget {
  final TextEditingController controller;
  final String description;
  final bool password;

  const FormTextInput(
      {super.key,
      required this.controller,
      required this.description,
      this.password = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(5.0),
        child: Column(
          children: [
            Padding(
                padding: const EdgeInsets.all(10.0),
                child: TextField(
                  controller: controller,
                  obscureText: password,
                  autocorrect: !password,
                  enableSuggestions: !password,
                )),
            Padding(
                padding: const EdgeInsets.all(10.0), child: Text(description)),
          ],
        ));
  }
}

class LoggedInMenu extends StatelessWidget {
  const LoggedInMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LoginInfo>(
        builder: (context, loginMenu, child) => AlertDialog(
              title: const Text("Logged In"),
              contentPadding: const EdgeInsets.all(5.0),
              content:
                  Text("Logged in as ${loginMenu.name} (${loginMenu.email})"),
              actions: [
                TextButton(
                    onPressed: () {
                      loginMenu
                          .logout()
                          .whenComplete(() => Navigator.pop(context, true));
                    },
                    child: const Text("Log Out"))
              ],
            ));
  }
}
