import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Thêm import này

class WeatherContainer extends StatefulWidget {
  final Map<String, dynamic>? weatherData;

  const WeatherContainer({super.key, this.weatherData});

  @override
  State<WeatherContainer> createState() => _WeatherContainerState();
}

class _WeatherContainerState extends State<WeatherContainer> {
  String _weatherInfo = "Loading weather...";
  TextEditingController _cityController = TextEditingController();
  final String apiKey = dotenv.env['OPENWEATHER_API'] ?? ''; // Lấy từ .env

  @override
  void initState() {
    super.initState();
    _updateWeatherInfo();
  }

  @override
  void didUpdateWidget(covariant WeatherContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.weatherData != oldWidget.weatherData) {
      _updateWeatherInfo();
    }
  }

  void _updateWeatherInfo() {
    if (widget.weatherData != null) {
      setState(() {
        _weatherInfo =
        "${widget.weatherData!['name']}: ${widget.weatherData!['main']['temp']}°C, ${widget.weatherData!['weather'][0]['description']}";
      });
    }
  }

  Future<void> _fetchWeatherFromCity(String city) async {
    if (apiKey.isEmpty) {
      setState(() {
        _weatherInfo = "API key is missing";
      });
      return;
    }

    final url =
        'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _weatherInfo =
          "${data['name']}: ${data['main']['temp']}°C, ${data['weather'][0]['description']}";
        });
      } else {
        setState(() {
          _weatherInfo = "City not found";
        });
      }
    } catch (e) {
      setState(() {
        _weatherInfo = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        children: [
          Text(
            _weatherInfo,
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _cityController,
            decoration: InputDecoration(
              labelText: "Enter city name",
              border: OutlineInputBorder(),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_cityController.text.isNotEmpty) {
                _fetchWeatherFromCity(_cityController.text);
              }
            },
            child: Text("Get Weather"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }
}