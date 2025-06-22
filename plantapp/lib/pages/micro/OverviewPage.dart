import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';

class OverviewPage extends StatefulWidget {
  final String regionName;
  final List<Map<String, dynamic>> devices;

  const OverviewPage({
    super.key,
    required this.regionName,
    required this.devices,
  });

  @override
  _OverviewPageState createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  Map<String, Map<String, dynamic>> deviceData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    // Lắng nghe dữ liệu thời gian thực cho từng thiết bị
    for (var device in widget.devices) {
      final deviceId = device['id'] as String;
      _dbRef.child('devices/$deviceId').onValue.listen((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
        setState(() {
          deviceData[deviceId] = Map<String, dynamic>.from(data);
          deviceData[deviceId]!['id'] = deviceId;
          deviceData[deviceId]!['name'] = data['name'] ?? device['name'] ?? 'Unnamed Device';
          _isLoading = false;
        });
      }, onError: (error) {
        print("Error listening to device $deviceId: $error");
        setState(() {
          _isLoading = false;
        });
      });
    }
  }

  String _getSoilCondition(double soilValue, double soilMin, double soilMax) {
    if (soilValue < soilMin) return "Độ ẩm đất thấp";
    if (soilValue > soilMax) return "Độ ẩm đất quá cao";
    return "Độ ẩm đất phù hợp";
  }

  Color _getSoilConditionColor(double soilValue, double soilMin, double soilMax) {
    if (soilValue < soilMin) return Colors.orange;
    if (soilValue > soilMax) return Colors.red;
    return Colors.green;
  }

  String _getMotorStatus(dynamic status) {
    if (status == 1 || status == "Bật") return "Bật";
    if (status == 0 || status == "Tắt") return "Tắt";
    if (status == 20) return "Tự động (Tắt)";
    if (status == 21) return "Tự động (Bật)";
    return "Không xác định";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Tổng quan: ${widget.regionName}",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 25,
          ),
        ),
        backgroundColor: const Color.fromRGBO(161, 207, 107, 1),
        elevation: 4,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(245, 250, 240, 1),
              Color.fromRGBO(220, 240, 210, 1),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : widget.devices.isEmpty
            ? const Center(
          child: Text(
            "Không có thiết bị trong khu vực này",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: widget.devices.length,
          itemBuilder: (context, index) {
            final device = widget.devices[index];
            final deviceId = device['id'] as String;
            final data = deviceData[deviceId] ?? device;
            final soilValue = double.tryParse(
              (data['doAmDat']?['current'] ?? 0).toString(),
            ) ??
                0;
            final soilMin =
                (data['doAmDat']?['min'] as num?)?.toDouble() ?? 70;
            final soilMax =
                (data['doAmDat']?['max'] as num?)?.toDouble() ?? 95;
            final motorStatus = data['mayBom']?['trangThai'] ?? 'N/A';

            return Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Container(
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
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] ?? 'Unnamed Device',
                        style: GoogleFonts.poppins(
                          color: const Color.fromRGBO(0, 100, 53, 1),
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Độ ẩm đất: $soilValue%",
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _getSoilCondition(
                                    soilValue, soilMin, soilMax),
                                style: GoogleFonts.poppins(
                                  color: _getSoilConditionColor(
                                      soilValue, soilMin, soilMax),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Máy bơm: ${_getMotorStatus(motorStatus)}",
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}