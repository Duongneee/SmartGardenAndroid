import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plantapp/pages/home/homebuttons.dart';
import 'package:plantapp/pages/micro/MicroDetails.dart';
import 'package:plantapp/pages/PlantIndentifyPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String? _currentEmail;
  String? _currentLocation;
  Map<String, dynamic>? _weatherData;
  final TextEditingController _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentUserEmail();
    _getWeatherFromLocation();
  }

  // lấy email
  void _getCurrentUserEmail() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _currentEmail = user?.email ?? 'User';
    });
  }

// lấy vị trí hiện tại và thời thiết hiện tại
  Future<void> _getWeatherFromLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _currentLocation = 'Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _currentLocation = 'Location permission denied');
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // lấy để hiển thị lên giao diện
      _currentLocation = await _getCityFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final apiKey = dotenv.env['OPENWEATHER_API'] ?? '';
      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=metric';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          _weatherData = json.decode(response.body);
        });
      }
    } catch (e) {
      print('Error getting weather: $e');
      setState(() => _currentLocation = 'Error getting location');
    }
  }

  Future<String> _getCityFromCoordinates(double lat, double lon) async {
    final apiKey = dotenv.env['OPENWEATHER_API'] ?? '';
    final url =
        'http://api.openweathermap.org/geo/1.0/reverse?lat=$lat&lon=$lon&limit=1&appid=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data[0]['name'] ?? 'Unknown Location';
    }
    return 'Unknown Location';
  }

  Future<void> _getWeatherFromCity(String city) async {
    try {
      final apiKey = dotenv.env['OPENWEATHER_API'] ?? '';
      final url =
          'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          _weatherData = json.decode(response.body);
          _currentLocation = city;
        });
      } else {
        setState(() {
          _currentLocation = 'City not found';
          _weatherData = null;
        });
      }
    } catch (e) {
      print('Error getting weather: $e');
      setState(() {
        _currentLocation = 'Error getting weather';
        _weatherData = null;
      });
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // Smart Garden
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text(
                "Smart Garden",
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 25),
              ),
            ],
          ),
        ),
        backgroundColor: const Color.fromRGBO(161, 207, 107, 1),
      ),
      body: ListView(
        children: [
          Stack(alignment: Alignment.bottomLeft, children: [
            Container(
              height: 150,
              width: 500,
              decoration: const BoxDecoration(
                  borderRadius:
                  BorderRadius.only(bottomRight: Radius.circular(81)),
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(161, 207, 107, 1),
                        Color.fromRGBO(74, 173, 82, 1)
                      ])),
            ),
            // Chào mừng
            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Wrap(direction: Axis.vertical, children: [
                Text.rich(TextSpan(
                  text: 'Welcome \n',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    height: 0.9,
                    fontWeight: FontWeight.w400,
                    fontSize: 28,
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text: '${_currentEmail?.split('@')[0] ?? 'User'}!',
                      style: GoogleFonts.poppins(
                        height: 0.8,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 35,
                      ),
                    ),
                  ],
                )),
                // Thời tiết
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Flex(
                    direction: Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_pin,
                        color: Colors.white,
                      ),
                      Text(
                        _currentLocation ?? 'Loading...',
                        style: GoogleFonts.poppins(color: Colors.white),
                      )
                    ],
                  ),
                )
              ]),
            )
          ]),
          // mục nhập địa điểm
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: TextField(
              controller: _cityController,
              decoration: InputDecoration(
                hintText: 'Enter city name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    if (_cityController.text.isNotEmpty) {
                      _getWeatherFromCity(_cityController.text);
                    }
                  },
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _getWeatherFromCity(value);
                }
              },
            ),
          ),
          _weatherData != null
              ? Container(
            margin: const EdgeInsets.all(15.0),
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white, // nền
              borderRadius: BorderRadius.circular(15.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'http://openweathermap.org/img/wn/${_weatherData?['weather'][0]['icon']}@2x.png',
                      width: 50,
                      height: 50,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "${_weatherData?['main']['temp']}°C",
                      style: GoogleFonts.poppins(
                          fontSize: 40, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _weatherData?['weather'][0]['description'] ??
                      "Weather Info",
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  "Humidity: ${_weatherData?['main']['humidity']}%",
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  "Wind Speed: ${_weatherData?['wind']['speed']} m/s",
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              ],
            ),
          )
              : Container(
            margin: const EdgeInsets.all(15.0),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
            child: GestureDetector( // hỗ trợ nhấn
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MicroPage()),
                  );
                },
                child: const ButtonsHome(
                  imgpath: "lib/images/iot.jpeg",
                  heading: "In Ground Sensors",
                )),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
            child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PlantIdentifyPage()),
                  );
                },
                child: const ButtonsHome(
                  imgpath: "lib/images/news.jpg",
                  heading: "Plant ID Chatbot",
                )),
          ),
        ],
      ),
    );
  }
}