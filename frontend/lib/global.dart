import 'package:google_sign_in/google_sign_in.dart';
//final String baseurl = "http://10.0.2.2:8080";

// final String baseurl = "http://192.168.1.148:8080";

late String baseurl;

String googleName = "";
String googleGmail = "";
String googleImageUrl = "";
GoogleSignInAccount? account;

//************** Google SingIn Starter && Google Sing Out ************ */

final GoogleSignIn googleSignIn = GoogleSignIn(
  serverClientId:
      "866885658869-abo5bnok75am8lbltqdj4b664n36m52h.apps.googleusercontent.com",
  scopes: [
    'https://www.googleapis.com/auth/userinfo.email',
    'openid',
  ],
);

Future<void> googleLogout() async {
  await googleSignIn.signOut();
  account = null;
}
