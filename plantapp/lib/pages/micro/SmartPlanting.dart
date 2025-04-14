import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plantapp/pages/micro/semicircle_indicator.dart';
import 'package:plantapp/services/notification_service.dart';

class SmartPlanting extends StatefulWidget {
  final Function(int) motorSwitch;
  final int motor;
  final Map<String, dynamic>? gardenData;
  final Function(String, Color) onSoilMoistureChange;

  const SmartPlanting({
    super.key,
    required this.motorSwitch,
    required this.motor,
    required this.gardenData,
    required this.onSoilMoistureChange,
  });

  @override
  _SmartPlantingState createState() => _SmartPlantingState();
}

class _SmartPlantingState extends State<SmartPlanting> {
  String sensedsoil = "0";
  double minHumidity = 0;
  double maxHumidity = 100;
  String soilMoistureCondition = "Loading...";
  Color soilMoistureColor = Colors.grey;

  late DatabaseReference _gardenRef;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    if (widget.gardenData != null) {
      _gardenRef = FirebaseDatabase.instance.ref().child("gardens/${widget.gardenData!['id']}");
      sensedsoil = widget.gardenData!['doAmDat']?['current']?.toString() ?? "0";
      minHumidity = (widget.gardenData!['doAmDat']?['min'] as num?)?.toDouble() ?? 0;
      maxHumidity = (widget.gardenData!['doAmDat']?['max'] as num?)?.toDouble() ?? 100;
      _setupGardenListener();
    }
  }

  void _setupGardenListener() {
    _gardenRef.onValue.listen((event) {
      if (event.snapshot.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Không thể tải dữ liệu khu vườn")),
        );
        return;
      }
      setState(() {
        final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
        final current = data['doAmDat']?['current'] as num?;
        sensedsoil = current?.toStringAsFixed(1) ?? "0";
        minHumidity = (data['doAmDat']?['min'] as num?)?.toDouble() ?? 0;
        maxHumidity = (data['doAmDat']?['max'] as num?)?.toDouble() ?? 100;

        if (current != null) {
          if (current < minHumidity) {
            soilMoistureCondition = "Độ ẩm đất quá thấp";
            soilMoistureColor = Colors.red;
          } else if (current > maxHumidity) {
            soilMoistureCondition = "Độ ẩm đất quá cao";
            soilMoistureColor = Colors.blue;
          } else {
            soilMoistureCondition = "Độ ẩm đất phù hợp";
            soilMoistureColor = Colors.green;
          }
          widget.onSoilMoistureChange(soilMoistureCondition, soilMoistureColor);

          if (current < minHumidity || current > maxHumidity) {
            if (widget.motor == 0 || widget.motor == 1) {
              _notificationService.showNotification(
                "Cảnh báo chế độ thủ công",
                "Độ ẩm đất ngoài phạm vi. Vui lòng điều chỉnh máy bơm thủ công.",
              );
            } else if (widget.motor == 20 || widget.motor == 21) {
              _notificationService.showNotification(
                "Cảnh báo chế độ tự động",
                "Độ ẩm đất ngoài phạm vi. Máy bơm đã được kích hoạt tự động.",
              );
            }
          }
        }
      });
    });
  }

  void _updateMinHumidity(double value) {
    if (value < maxHumidity) {
      setState(() {
        minHumidity = value;
      });
      _gardenRef.child('doAmDat').update({'min': value});
    }
  }

  void _updateMaxHumidity(double value) {
    if (value > minHumidity) {
      setState(() {
        maxHumidity = value;
      });
      _gardenRef.child('doAmDat').update({'max': value});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Smart Watering",
            style: GoogleFonts.poppins(
              color: const Color.fromRGBO(0, 100, 53, 1),
              fontWeight: FontWeight.w600,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200, // Giới hạn chiều cao của biểu đồ
            child: CustomSemicircularIndicator(
              radius: 100,
              progress: (double.tryParse(sensedsoil) ?? 0) / 100,
              color: const Color.fromRGBO(151, 203, 104, 1),
              backgroundColor: const Color.fromRGBO(0, 100, 53, 0.2),
              strokeWidth: 25,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end, // Căn giữa theo chiều dọc
                children: [
                  Text(
                    '$sensedsoil%',
                    style: GoogleFonts.poppins(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: const Color.fromRGBO(0, 100, 53, 1),
                    ),
                    textAlign: TextAlign.center, // Căn giữa văn bản
                  ),
                  Text(
                    'Soil Moisture',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center, // Căn giữa văn bản
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25), // Khoảng cách sau biểu đồ
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Text(
                  "Min Humidity: ${minHumidity.toStringAsFixed(1)}%",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: minHumidity,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: minHumidity.toStringAsFixed(1),
                  onChanged: _updateMinHumidity,
                  activeColor: const Color.fromRGBO(74, 173, 82, 1),
                  inactiveColor: Colors.grey[300],
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Text(
                  "Max Humidity: ${maxHumidity.toStringAsFixed(1)}%",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: maxHumidity,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: maxHumidity.toStringAsFixed(1),
                  onChanged: _updateMaxHumidity,
                  activeColor: const Color.fromRGBO(74, 173, 82, 1),
                  inactiveColor: Colors.grey[300],
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: () {
                  widget.motorSwitch(widget.motor == 1 ? 0 : 1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 140,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.motor == 1 ? Colors.red : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.motor == 1 ? "Manual On" : "Manual Off",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: widget.motor == 1 ? Colors.white : Colors.black,
                        fontWeight: widget.motor == 1 ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  widget.motorSwitch((widget.motor == 20 || widget.motor == 21) ? 0 : 20);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 140,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (widget.motor == 20 || widget.motor == 21)
                        ? const Color.fromRGBO(74, 173, 82, 1)
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      (widget.motor == 20 || widget.motor == 21) ? "Auto On" : "Auto Off",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: (widget.motor == 20 || widget.motor == 21) ? Colors.white : Colors.black,
                        fontWeight: (widget.motor == 20 || widget.motor == 21) ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}