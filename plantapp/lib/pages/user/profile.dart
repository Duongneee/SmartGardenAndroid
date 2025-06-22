import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../userdets.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    String username = Provider.of<UserInfo>(context, listen: false).name;
    String location = Provider.of<UserInfo>(context, listen: false).location;
    // String plant = Provider.of<UserInfo>(context, listen: false).plant;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        iconTheme: IconThemeData(
          color:
              Colors.white,
        ),
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text(
                "Smart Garden",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 25,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Color.fromRGBO(161, 207, 107, 1),
        actions: [
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                );
              },
              child: Icon(Icons.person, color: Colors.white),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: 70,
                width: 500,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(50),
                    bottomLeft: Radius.circular(50),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromRGBO(161, 207, 107, 1),
                      Color.fromRGBO(74, 173, 82, 1),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "User Profile",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        height: 0.9,
                        fontWeight: FontWeight.w600,
                        fontSize: 28,
                      ),
                    ),
                    SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: CircleAvatar(
              radius: 60,
              backgroundColor:
                  Colors.grey[300],
              child: Icon(
                Icons.person,
                size: 100,
                color: Colors.grey[600],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              children: [
                ListTile(
                  leading: Icon(Icons.person),
                  title: Text("Username"),
                  subtitle: Text(username),
                ),
                ListTile(
                  leading: Icon(Icons.location_on),
                  title: Text("Location"),
                  subtitle: Text(location),
                ),
                // ListTile(
                //   leading: Icon(Icons.eco),
                //   title: Text("Plant"),
                //   subtitle: Text(plant),
                // ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
