import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:plantapp/pages/micro/sensordets.dart';
import 'package:plantapp/pages/PlantIndentifyPage.dart';
import 'package:plantapp/pages/micro/SmartPlanting.dart';

class NodeDetails extends StatefulWidget {
  final Map<String, dynamic> garden;

  const NodeDetails({super.key, required this.garden});

  @override
  State<NodeDetails> createState() => _NodeDetailsState();
}

class _NodeDetailsState extends State<NodeDetails> {
  late DatabaseReference _gardenRef;
  TextEditingController _intervalController = TextEditingController();

  String sensedsoil = "0";
  int motor = 0;
  double soilMax = 95;
  double soilMin = 70;
  int dataInterval = 60;

  String soilMoistureCondition = "Loading...";
  Color soilMoistureColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _gardenRef = FirebaseDatabase.instance.ref().child('gardens/${widget.garden['id']}');

    sensedsoil = widget.garden['doAmDat']?['current']?.toString() ?? "0";
    soilMin = (widget.garden['doAmDat']?['min'] as num?)?.toDouble() ?? 70;
    soilMax = (widget.garden['doAmDat']?['max'] as num?)?.toDouble() ?? 95;
    motor = widget.garden['mayBom']?['trangThai'] == "Bật" ? 1 : 0;
    dataInterval = widget.garden['time'] ?? 60;
    _intervalController.text = dataInterval.toString();

    _setupListeners();
  }

  void _setupListeners() {
    _gardenRef.onValue.listen((event) {
      final gardenData = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      setState(() {
        sensedsoil = (gardenData['doAmDat']?['current'] ?? 0).toString();
        soilMin = (gardenData['doAmDat']?['min'] as num?)?.toDouble() ?? 70;
        soilMax = (gardenData['doAmDat']?['max'] as num?)?.toDouble() ?? 95;
        motor = gardenData['mayBom']?['trangThai'] == "Bật" ? 1 : 0;
        dataInterval = gardenData['time'] ?? 60;
        _intervalController.text = dataInterval.toString();

        final soilValue = double.tryParse(sensedsoil) ?? 0;
        if (soilValue < soilMin) {
          soilMoistureCondition = "Độ ẩm đất thấp";
          soilMoistureColor = Colors.orange;
        } else if (soilValue > soilMax) {
          soilMoistureCondition = "Độ ẩm đất quá cao";
          soilMoistureColor = Colors.red;
        } else {
          soilMoistureCondition = "Độ ẩm đất phù hợp";
          soilMoistureColor = Colors.green;
        }
      });
    });
  }

  void motorSwitch(int valueStateOfMayBom) async {
    setState(() {
      motor = valueStateOfMayBom;
    });
    await _gardenRef.child('mayBom').update({'trangThai': motor == 1 ? "Bật" : "Tắt"});
  }

  void handleSoilMoistureChange(String condition, Color color) {
    setState(() {
      soilMoistureCondition = condition;
      soilMoistureColor = color;
    });
  }

  void _updateDataInterval(String value) {
    final int? interval = int.tryParse(value);
    if (interval != null && interval > 0) {
      setState(() {
        dataInterval = interval;
      });
      _gardenRef.update({'time': interval});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã cập nhật khoảng thời gian gửi dữ liệu")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập số giây hợp lệ")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Smart Garden",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 25,
          ),
        ),
        backgroundColor: const Color.fromRGBO(161, 207, 107, 1),
        elevation: 4,
        actions: const [
          Padding(
            padding: EdgeInsets.all(15.0),
            child: Icon(Icons.person, color: Colors.white),
          ),
        ],
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
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
                  children: [
                    Text(
                      "Garden Details",
                      style: GoogleFonts.poppins(
                        color: const Color.fromRGBO(0, 100, 53, 1),
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.garden['name'],
                      style: GoogleFonts.poppins(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'lib/images/plant.png',
                  height: 300,
                  width: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromRGBO(161, 207, 107, 1),
                      Color.fromRGBO(74, 173, 82, 1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center, // Căn giữa theo chiều ngang
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: soilMoistureColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        soilMoistureCondition,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 15),
                    SensorDetails(
                      sensedval: "$sensedsoil%",
                      icon: Icons.grass,
                      stype: "Soil Moisture",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Khoảng thời gian gửi dữ liệu",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color.fromRGBO(0, 100, 53, 1),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _intervalController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Giây",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => _updateDataInterval(_intervalController.text),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: const Color.fromRGBO(74, 173, 82, 1),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: Text(
                            "Cập nhật",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      showInformation(context, widget.garden);
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: const Color.fromRGBO(74, 173, 82, 1),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      elevation: 3,
                    ),
                    child: Text(
                      "Garden Info",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PlantIdentifyPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: const Color.fromRGBO(74, 173, 82, 1),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      elevation: 3,
                    ),
                    child: Text(
                      "Plant ID",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              SmartPlanting(
                motorSwitch: motorSwitch,
                motor: motor,
                gardenData: widget.garden,
                onSoilMoistureChange: handleSoilMoistureChange,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void showInformation(BuildContext context, Map<String, dynamic> garden) {
    final doAmDat = garden['doAmDat'] as Map<String, dynamic>? ?? {};
    final mayBom = garden['mayBom'] as Map<String, dynamic>? ?? {};
    final location = garden['location'] as Map<String, dynamic>? ?? {};
    final history = doAmDat['history'] as Map<String, dynamic>? ?? {};

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(color: const Color.fromRGBO(74, 173, 82, 1), fontWeight: FontWeight.w600),
              ),
            ),
          ],
          title: Text(
            'Garden Information',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 20, color: const Color.fromRGBO(0, 100, 53, 1)),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset('lib/images/1.jpg', height: 100, fit: BoxFit.cover),
                ),
                const SizedBox(height: 15),
                Text(
                  garden['name'].toUpperCase(),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.green),
                ),
                const SizedBox(height: 15),
                Text(
                  "Độ ẩm đất:",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.grey[800]),
                ),
                Text("Hiện tại: ${doAmDat['current'] ?? 'N/A'}%", style: GoogleFonts.poppins(fontSize: 16)),
                Text("Tối đa: ${doAmDat['max'] ?? 'N/A'}%", style: GoogleFonts.poppins(fontSize: 16)),
                Text("Tối thiểu: ${doAmDat['min'] ?? 'N/A'}%", style: GoogleFonts.poppins(fontSize: 16)),
                const SizedBox(height: 15),
                if (history.isNotEmpty) ...[
                  Text(
                    "Lịch sử độ ẩm:",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.grey[800]),
                  ),
                  ...history.entries.map((entry) {
                    final data = entry.value as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text("${data['time']}: ${data['value']}%", style: GoogleFonts.poppins(fontSize: 16)),
                    );
                  }).toList(),
                  const SizedBox(height: 15),
                ],
                Text(
                  "Máy bơm:",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.grey[800]),
                ),
                Text("Trạng thái: ${mayBom['trangThai'] ?? 'N/A'}", style: GoogleFonts.poppins(fontSize: 16)),
                const SizedBox(height: 15),
                if (location.isNotEmpty) ...[
                  Text(
                    "Vị trí:",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.grey[800]),
                  ),
                  Text("Latitude: ${location['Latitude'] ?? 'N/A'}", style: GoogleFonts.poppins(fontSize: 16)),
                  Text("Longitude: ${location['Longitude'] ?? 'N/A'}", style: GoogleFonts.poppins(fontSize: 16)),
                  const SizedBox(height: 15),
                ],
                Text(
                  "Khoảng thời gian gửi dữ liệu:",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.grey[800]),
                ),
                Text("${garden['time'] ?? 'N/A'} giây", style: GoogleFonts.poppins(fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );
  }
}