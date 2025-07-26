import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestLocationPermission() async {
  var status = await Permission.location.status;
  if (!status.isGranted) {
    status = await Permission.location.request();
  }
  return status.isGranted;
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? currentWeather;
  List<dynamic>? dailyForecast;
  bool loading = true;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    setState(() => loading = true);

    try {
      Position position = await _determinePosition();

      final lat = position.latitude;
      final lon = position.longitude;

      // Open-Meteo API call with humidity and wind direction added
      final url =
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&daily=temperature_2m_max,temperature_2m_min,weathercode&hourly=relativehumidity_2m,winddirection_10m&timezone=auto';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          currentWeather = data['current_weather'];
          dailyForecast = data['daily'] != null
              ? List.generate(data['daily']['time'].length, (index) {
                  return {
                    "date": data['daily']['time'][index],
                    "max": data['daily']['temperature_2m_max'][index],
                    "min": data['daily']['temperature_2m_min'][index],
                    "weathercode": data['daily']['weathercode'][index],
                  };
                })
              : null;
          loading = false;
        });

        _controller.forward(from: 0);
      } else {
        throw Exception('Failed to fetch weather');
      }
    } catch (e) {
      setState(() {
        loading = false;
        currentWeather = null;
        dailyForecast = null;
      });
      debugPrint('Error fetching weather: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching weather data: $e')),
      );
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw Exception('Location permissions are denied.');
      }
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  String _getWeatherIcon(int code) {
    if (code == 0) return "☀️";
    if (code == 1 || code == 2 || code == 3) return "🌤️";
    if (code == 45 || code == 48) return "🌫️";
    if (code == 51 || code == 53 || code == 55) return "🌦️";
    if (code == 61 || code == 63 || code == 65) return "🌧️";
    if (code == 71 || code == 73 || code == 75) return "🌨️";
    if (code == 80 || code == 81 || code == 82) return "🌧️";
    if (code == 95) return "⛈️";
    if (code == 96 || code == 99) return "⛈️";
    return "❓";
  }

  String _getDangerLevel(int code) {
    // Simple danger level based on weather code severity
    if (code == 95 || code == 96 || code == 99) {
      return "⚠️ Severe Thunderstorm";
    } else if (code == 71 || code == 73 || code == 75) {
      return "⚠️ Snowy Conditions";
    } else if (code == 61 ||
        code == 63 ||
        code == 65 ||
        code == 80 ||
        code == 81) {
      return "⚠️ Rainy Weather";
    } else if (code == 45 || code == 48) {
      return "⚠️ Foggy Conditions";
    } else {
      return "Normal Weather";
    }
  }

  String _formatWindDirection(num degrees) {
    const directions = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW',
      'N',
    ];
    final index = ((degrees / 22.5) + 0.5).floor() % 16;
    return directions[index];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showDangerInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Weather Danger Levels"),
        content: const Text(
          "⚠️ Severe Thunderstorm: Dangerous weather with lightning and hail.\n"
          "⚠️ Snowy Conditions: Heavy snow may cause travel disruptions.\n"
          "⚠️ Rainy Weather: Heavy rain may cause flooding or slippery roads.\n"
          "⚠️ Foggy Conditions: Reduced visibility, drive carefully.\n"
          "Normal Weather: No significant hazards.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No appBar title per your request
      backgroundColor: Colors.blue.shade50,
      floatingActionButton: FloatingActionButton(
        onPressed: _showDangerInfoDialog,
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.info_outline),
        tooltip: "Weather Danger Info",
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : currentWeather == null
          ? Center(
              child: Text(
                "Failed to load weather data",
                style: TextStyle(fontSize: 18, color: Colors.red.shade700),
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Current Weather Card
                      Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        color: Colors.white,
                        shadowColor: Colors.blue.shade200,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 24,
                            horizontal: 20,
                          ),
                          width: double.infinity,
                          child: Column(
                            children: [
                              Text(
                                "${currentWeather!['temperature'].toStringAsFixed(1)}°C",
                                style: TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _getWeatherIcon(
                                      currentWeather!['weathercode'],
                                    ) +
                                    " ${_getDangerLevel(currentWeather!['weathercode'])}",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _infoColumn(
                                    "Wind",
                                    "${currentWeather!['windspeed']} km/h\n${_formatWindDirection(currentWeather!['winddirection'])}",
                                  ),
                                  _infoColumn(
                                    "Updated",
                                    DateFormat('hh:mm a').format(
                                      DateTime.parse(currentWeather!['time']),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // 7-day Forecast Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "7-Day Forecast",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.refresh,
                              color: Colors.blue.shade700,
                            ),
                            onPressed: _fetchWeather,
                            tooltip: "Refresh Weather",
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 7-day Forecast Cards
                      Expanded(
                        child: dailyForecast == null
                            ? const Center(child: Text("No forecast available"))
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: dailyForecast!.length,
                                itemBuilder: (context, index) {
                                  final day = dailyForecast![index];
                                  final date = DateFormat(
                                    'E, MMM d',
                                  ).format(DateTime.parse(day['date']));
                                  final icon = _getWeatherIcon(
                                    day['weathercode'],
                                  );
                                  final danger = _getDangerLevel(
                                    day['weathercode'],
                                  );

                                  return Container(
                                    width: 140,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      elevation: 4,
                                      color: Colors.white,
                                      shadowColor: Colors.blue.shade100,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              date,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.blue.shade800,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              icon,
                                              style: const TextStyle(
                                                fontSize: 44,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              "Max: ${day['max'].toStringAsFixed(1)}°C",
                                              style: TextStyle(
                                                color: Colors.red.shade400,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              "Min: ${day['min'].toStringAsFixed(1)}°C",
                                              style: TextStyle(
                                                color: Colors.blue.shade600,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              danger,
                                              style: TextStyle(
                                                color: danger.startsWith("⚠️")
                                                    ? Colors.red.shade700
                                                    : Colors.green.shade700,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _infoColumn(String label, String value, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // important!
        children: [
          if (icon != null) Icon(icon, color: Colors.blue.shade700, size: 26),
          if (icon != null) const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue.shade800,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
