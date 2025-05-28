import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class NodeDetails extends StatefulWidget {
  final Map<String, dynamic> garden;

  const NodeDetails({super.key, required this.garden});

  @override
  State<NodeDetails> createState() => _NodeDetailsState();
}

class _NodeDetailsState extends State<NodeDetails> {
  late DatabaseReference _gardenRef;
  TextEditingController _intervalController = TextEditingController();
  TextEditingController _gardenNameController = TextEditingController();

  String sensedsoil = "0";
  int motor = 0; // 0: Tắt, 1: Bật, 20: Tự động (tắt), 21: Tự động (bật)
  double soilMax = 95;
  double soilMin = 70;
  int dataInterval = 60;
  String gardenName = "";
  Map<String, dynamic> history = {};
  List<FlSpot> spots = [];
  List<String> timeLabels = [];

  String soilMoistureCondition = "Loading...";
  Color soilMoistureColor = Colors.grey;

  double minX = 0;
  double maxX = 1;
  double minY = 0;
  double maxY = 100;

  @override
  void initState() {
    super.initState();
    _gardenRef = FirebaseDatabase.instance.ref().child('gardens/${widget.garden['id']}');

    sensedsoil = widget.garden['doAmDat']?['current']?.toString() ?? "0";
    soilMin = (widget.garden['doAmDat']?['min'] as num?)?.toDouble() ?? 70;
    soilMax = (widget.garden['doAmDat']?['max'] as num?)?.toDouble() ?? 95;
    motor = _parseMotorStatus(widget.garden['mayBom']?['trangThai']);
    dataInterval = widget.garden['time'] ?? 60;
    gardenName = widget.garden['name'] ?? '';
    _intervalController.text = dataInterval.toString();
    _gardenNameController.text = gardenName;

    _setupListeners();
  }

  int _parseMotorStatus(dynamic status) {
    if (status == "Bật" || status == 1) return 1;
    if (status == "Tắt" || status == 0) return 0;
    if (status == 20) return 20;
    if (status == 21) return 21;
    return 0; // Mặc định là Tắt nếu không xác định
  }

  String _getMotorStatusText(int status) {
    switch (status) {
      case 1:
        return "Máy bơm: Bật";
      case 0:
        return "Máy bơm: Tắt";
      case 20:
        return "Máy bơm: Tự động (Tắt)";
      case 21:
        return "Máy bơm: Tự động (Bật)";
      default:
        return "Máy bơm: Không xác định";
    }
  }

  void _setupListeners() {
    _gardenRef.onValue.listen((event) {
      final gardenData = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      setState(() {
        sensedsoil = (gardenData['doAmDat']?['current'] ?? 0).toString();
        soilMin = (gardenData['doAmDat']?['min'] as num?)?.toDouble() ?? 70;
        soilMax = (gardenData['doAmDat']?['max'] as num?)?.toDouble() ?? 95;
        motor = _parseMotorStatus(gardenData['mayBom']?['trangThai']);
        dataInterval = gardenData['time'] ?? 60;
        gardenName = gardenData['name'] ?? widget.garden['name'];

        history = {};
        final historyRaw = gardenData['doAmDat']?['history'];
        if (historyRaw is Map) {
          history = Map<String, dynamic>.from(
            historyRaw.map((key, value) => MapEntry(key.toString(), value)),
          );
        }

        spots.clear();
        timeLabels.clear();
        if (history.isNotEmpty) {
          final sortedEntries = history.entries.toList()
            ..sort((a, b) {
              try {
                final timeA = a.value['time'] as String?;
                final timeB = b.value['time'] as String?;
                if (timeA == null || timeB == null) return 0;
                return DateTime.parse(timeA).compareTo(DateTime.parse(timeB));
              } catch (e) {
                return 0;
              }
            });
          for (int i = 0; i < sortedEntries.length; i++) {
            final entry = sortedEntries[i].value;
            try {
              final time = entry['time'] as String?;
              final value = entry['value'];
              if (time != null && value is num) {
                final parsedTime = DateTime.parse(time);
                spots.add(FlSpot(i.toDouble(), value.toDouble()));
                timeLabels.add(DateFormat('dd/MM HH:mm').format(parsedTime));
              }
            } catch (e) {
              // Bỏ qua nếu dữ liệu không hợp lệ
            }
          }
        }

        minX = 0;
        maxX = spots.isNotEmpty ? (spots.length - 1).toDouble() : 1;
        minY = spots.isNotEmpty
            ? spots.map((e) => e.y).reduce((a, b) => a < b ? a : b) - 10
            : 0;
        maxY = spots.isNotEmpty
            ? spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 10
            : 100;

        _intervalController.text = dataInterval.toString();
        _gardenNameController.text = gardenName;

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

  void motorSwitch(int newMode) async {
    setState(() {
      motor = newMode;
    });

    int firebaseValue = newMode == 20 ? 20 : newMode;
    await _gardenRef.child('mayBom').update({
      'trangThai': firebaseValue,
    });
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

  void _updateSoilMoistureRange(double newMin, double newMax) async {
    if (newMin >= 0 && newMax <= 100 && newMin < newMax) {
      setState(() {
        soilMin = newMin;
        soilMax = newMax;
      });
      await _gardenRef.child('doAmDat').update({
        'min': newMin,
        'max': newMax,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã cập nhật ngưỡng độ ẩm đất")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Giá trị không hợp lệ (0-100, min < max)")),
      );
    }
  }

  void _renameGarden() {
    showDialog(
      context: context,
      builder: (context) {
        _gardenNameController.text = gardenName;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Đổi tên khu vườn',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: const Color.fromRGBO(0, 100, 53, 1),
            ),
          ),
          content: TextField(
            controller: _gardenNameController,
            decoration: InputDecoration(
              labelText: "Tên khu vườn",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              errorText: _gardenNameController.text.trim().isEmpty
                  ? 'Tên không được để trống'
                  : null,
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Hủy',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final newName = _gardenNameController.text.trim();
                if (newName.isNotEmpty) {
                  try {
                    await _gardenRef.update({'name': newName});
                    setState(() {
                      gardenName = newName;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Đã đổi tên khu vườn")),
                    );
                    Navigator.of(context).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Lỗi khi đổi tên: $e")),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Tên khu vườn không được để trống")),
                  );
                }
              },
              child: Text(
                'OK',
                style: GoogleFonts.poppins(
                  color: const Color.fromRGBO(74, 173, 82, 1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteGarden() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Xóa khu vườn',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: const Color.fromRGBO(0, 100, 53, 1),
            ),
          ),
          content: Text(
            'Bạn có chắc chắn muốn ngừng truy cập khu vườn "$gardenName" không? Khu vườn sẽ không bị xóa, chỉ bị ẩn khỏi danh sách của bạn.',
            style: GoogleFonts.poppins(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Hủy',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final userId = FirebaseAuth.instance.currentUser?.uid;
                  if (userId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Không tìm thấy người dùng. Vui lòng đăng nhập lại.")),
                    );
                    return;
                  }

                  await FirebaseDatabase.instance
                      .ref()
                      .child('users/$userId/gardens/${widget.garden['id']}')
                      .set(false);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Đã ẩn khu vườn khỏi danh sách của bạn")),
                  );
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Lỗi khi ẩn khu vườn: $e")),
                  );
                }
              },
              child: Text(
                'Xác nhận',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            gardenName,
                            style: GoogleFonts.poppins(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w600,
                              fontSize: 20,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color.fromRGBO(74, 173, 82, 1)),
                          onPressed: _renameGarden,
                          tooltip: 'Đổi tên khu vườn',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: _deleteGarden,
                          tooltip: 'Xóa khu vườn',
                        ),
                      ],
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
                  crossAxisAlignment: CrossAxisAlignment.center,
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
              // Biểu đồ lịch sử độ ẩm
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
                      "Lịch sử độ ẩm",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color.fromRGBO(0, 100, 53, 1),
                      ),
                    ),
                    const SizedBox(height: 10),
                    history.isNotEmpty && spots.isNotEmpty
                        ? Column(
                      children: [
                        SizedBox(
                          height: 250,
                          child: LineChart(
                            LineChartData(
                              lineTouchData: LineTouchData(
                                enabled: true,
                                handleBuiltInTouches: true,
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipColor: (LineBarSpot touchedSpot) => Colors.blueGrey,
                                  getTooltipItems: (touchedSpots) {
                                    return touchedSpots.map((spot) {
                                      final index = spot.x.toInt();
                                      return LineTooltipItem(
                                        '${timeLabels[index]}\n${spot.y.toStringAsFixed(1)}%',
                                        GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                                getTouchedSpotIndicator:
                                    (LineChartBarData barData, List<int> spotIndexes) {
                                  return spotIndexes.map((index) {
                                    return TouchedSpotIndicatorData(
                                      FlLine(
                                        color: Colors.blue,
                                        strokeWidth: 2,
                                      ),
                                      FlDotData(
                                        show: true,
                                        getDotPainter: (spot, percent, barData, index) =>
                                            FlDotCirclePainter(
                                              radius: 6,
                                              color: Colors.white,
                                              strokeWidth: 2,
                                              strokeColor: Colors.blue,
                                            ),
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: Colors.grey.withOpacity(0.2),
                                    strokeWidth: 1,
                                  );
                                },
                                getDrawingVerticalLine: (value) {
                                  return FlLine(
                                    color: Colors.grey.withOpacity(0.2),
                                    strokeWidth: 1,
                                  );
                                },
                              ),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 60,
                                    interval: spots.length > 10 ? spots.length / 5 : 1,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index >= 0 && index < timeLabels.length) {
                                        String label = timeLabels[index].split(' ')[0];
                                        if (index > 0 &&
                                            timeLabels[index].split(' ')[0] ==
                                                timeLabels[index - 1].split(' ')[0]) {
                                          label = timeLabels[index].split(' ')[1];
                                        }
                                        return SideTitleWidget(
                                          axisSide: meta.axisSide,
                                          angle: 45 * 3.141592653589793 / 180,
                                          child: Text(
                                            label,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        '${value.toInt()}%',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[800],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(color: Colors.grey.withOpacity(0.5)),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  color: const Color.fromRGBO(74, 173, 82, 1),
                                  barWidth: 3,
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: const Color.fromRGBO(74, 173, 82, 0.2),
                                  ),
                                  dotData: FlDotData(show: true),
                                ),
                              ],
                              minX: minX,
                              maxX: maxX,
                              minY: minY,
                              maxY: maxY,
                              clipData: FlClipData(
                                top: true,
                                bottom: true,
                                left: true,
                                right: true,
                              ),
                              extraLinesData: ExtraLinesData(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  final currentRangeX = maxX - minX;
                                  final currentRangeY = maxY - minY;
                                  minX += currentRangeX * 0.1;
                                  maxX -= currentRangeX * 0.1;
                                  minY += currentRangeY * 0.1;
                                  maxY -= currentRangeY * 0.1;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                backgroundColor: const Color.fromRGBO(74, 173, 82, 1),
                              ),
                              child: Text(
                                "Zoom In",
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  minX = 0;
                                  maxX = spots.isNotEmpty ? (spots.length - 1).toDouble() : 1;
                                  minY = spots.isNotEmpty
                                      ? spots.map((e) => e.y).reduce((a, b) => a < b ? a : b) - 10
                                      : 0;
                                  maxY = spots.isNotEmpty
                                      ? spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 10
                                      : 100;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                backgroundColor: const Color.fromRGBO(74, 173, 82, 1),
                              ),
                              child: Text(
                                "Zoom Out",
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                        : Text(
                      "Không có dữ liệu lịch sử.",
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Khoảng thời gian gửi dữ liệu
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
              // Điều chỉnh ngưỡng độ ẩm đất
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
                      "Ngưỡng độ ẩm đất",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color.fromRGBO(0, 100, 53, 1),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Min: ${soilMin.toStringAsFixed(1)}%",
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        Text(
                          "Max: ${soilMax.toStringAsFixed(1)}%",
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: RangeValues(soilMin, soilMax),
                      min: 0,
                      max: 100,
                      divisions: 100,
                      activeColor: const Color.fromRGBO(74, 173, 82, 1),
                      inactiveColor: Colors.grey[300],
                      labels: RangeLabels(
                        soilMin.toStringAsFixed(1),
                        soilMax.toStringAsFixed(1),
                      ),
                      onChanged: (RangeValues values) {
                        setState(() {
                          soilMin = values.start;
                          soilMax = values.end;
                        });
                      },
                      onChangeEnd: (RangeValues values) {
                        _updateSoilMoistureRange(values.start, values.end);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
}

class SensorDetails extends StatelessWidget {
  final String sensedval;
  final IconData icon;
  final String stype;

  const SensorDetails({
    super.key,
    required this.sensedval,
    required this.icon,
    required this.stype,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color.fromRGBO(74, 173, 82, 1)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stype,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                sensedval,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color.fromRGBO(74, 173, 82, 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SmartPlanting extends StatelessWidget {
  final Function(int) motorSwitch;
  final int motor;
  final Map<String, dynamic> gardenData;
  final Function(String, Color) onSoilMoistureChange;

  const SmartPlanting({
    super.key,
    required this.motorSwitch,
    required this.motor,
    required this.gardenData,
    required this.onSoilMoistureChange,
  });

  String _getMotorStatusText(int status) {
    switch (status) {
      case 1:
        return "Máy bơm: Bật";
      case 0:
        return "Máy bơm: Tắt";
      case 20:
        return "Máy bơm: Tự động (Tắt)";
      case 21:
        return "Máy bơm: Tự động (Bật)";
      default:
        return "Máy bơm: Không xác định";
    }
  }

  @override
  Widget build(BuildContext context) {
    List<bool> isSelected = [
      motor == 1,
      motor == 0,
      motor == 20 || motor == 21,
    ];

    return Container(
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
            "Điều khiển máy bơm",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color.fromRGBO(0, 100, 53, 1),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _getMotorStatusText(motor),
            style: GoogleFonts.poppins(fontSize: 16),
          ),
          const SizedBox(height: 15),
          Center(
            child: ToggleButtons(
              isSelected: isSelected,
              onPressed: (int index) {
                int newMode;
                if (index == 0) {
                  newMode = 1; // Bật
                } else if (index == 1) {
                  newMode = 0; // Tắt
                } else {
                  newMode = 20; // Tự động
                }
                motorSwitch(newMode);
              },
              color: Colors.grey,
              selectedColor: Colors.white,
              fillColor: const Color.fromRGBO(74, 173, 82, 1),
              borderRadius: BorderRadius.circular(10),
              borderColor: Colors.grey[300],
              selectedBorderColor: const Color.fromRGBO(74, 173, 82, 1),
              constraints: const BoxConstraints(
                minHeight: 50,
                minWidth: 80,
              ),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Icon(Icons.power),
                      SizedBox(width: 5),
                      Text("Bật"),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Icon(Icons.power_off),
                      SizedBox(width: 5),
                      Text("Tắt"),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Icon(Icons.autorenew),
                      SizedBox(width: 5),
                      Text("Tự động"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}