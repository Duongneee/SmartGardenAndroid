import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:plantapp/pages/micro/NodeDetails.dart';
import 'package:plantapp/pages/micro/AddPotPage.dart';
import 'package:plantapp/pages/micro/OverviewPage.dart';

class MicroPage extends StatefulWidget {
  const MicroPage({super.key});

  @override
  _MicroPageState createState() => _MicroPageState();
}

class _MicroPageState extends State<MicroPage> {
  Map<String, List<Map<String, dynamic>>> groupedDevices = {};
  List<Map<String, dynamic>> allDevices = [];
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  void _loadDevices() async {
    final user = _auth.currentUser;
    if (user == null) {
      print("User not logged in");
      setState(() {
        groupedDevices = {};
        allDevices = [];
        _isLoading = false;
      });
      return;
    }

    final userDevicesRef = _dbRef.child('users/${user.uid}/devices');
    final devicesRef = _dbRef.child('devices');
    final groupsRef = _dbRef.child('users/${user.uid}/groups');

    try {
      final userDeviceSnapshot = await userDevicesRef.once();
      final deviceSnapshot = await devicesRef.once();
      final groupSnapshot = await groupsRef.once();

      final userDeviceData = userDeviceSnapshot.snapshot.value as Map<dynamic, dynamic>? ?? {};
      final allDevicesData = deviceSnapshot.snapshot.value as Map<dynamic, dynamic>? ?? {};
      final groupsData = groupSnapshot.snapshot.value as Map<dynamic, dynamic>? ?? {};

      // Lọc các deviceId có trạng thái true
      final userDeviceIds = userDeviceData.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key.toString())
          .toList();

      // Lấy thông tin chi tiết của các thiết bị có trạng thái true
      allDevices = userDeviceIds
          .where((id) => allDevicesData[id] != null)
          .map((id) => {
        'id': id,
        ...Map<String, dynamic>.from(allDevicesData[id] as Map),
      })
          .toList();

      final Map<String, List<Map<String, dynamic>>> tempGroupedDevices = {
        'Chưa phân khu': [],
      };

      groupsData.forEach((groupId, groupData) {
        final groupName = groupData['name'] as String? ?? 'Unnamed Group';
        tempGroupedDevices[groupName] = [];
      });

      for (var device in allDevices) {
        bool assigned = false;
        groupsData.forEach((groupId, groupData) {
          final groupName = groupData['name'] as String? ?? 'Unnamed Group';
          final groupDevices = (groupData['devices'] as Map<dynamic, dynamic>?) ?? {};
          if (groupName != 'Chưa phân khu' &&
              groupDevices.containsKey(device['id']) &&
              groupDevices[device['id']] == true) {
            tempGroupedDevices[groupName]!.add(device);
            assigned = true;
          }
        });
        if (!assigned) {
          tempGroupedDevices['Chưa phân khu']!.add(device);
        }
      }

      setState(() {
        groupedDevices = tempGroupedDevices;
        _isLoading = false;
        print("Loaded allDevices: $allDevices");
        print("Grouped devices: $groupedDevices");
      });

      // Thêm listener thời gian thực cho từng thiết bị
      for (var device in allDevices) {
        final deviceId = device['id'] as String;
        _dbRef.child('devices/$deviceId').onValue.listen((event) {
          final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
          setState(() {
            final index = allDevices.indexWhere((d) => d['id'] == deviceId);
            if (index != -1) {
              allDevices[index] = {
                'id': deviceId,
                ...Map<String, dynamic>.from(data),
              };
              // Cập nhật groupedDevices
              groupedDevices.forEach((groupName, devices) {
                final deviceIndex = devices.indexWhere((d) => d['id'] == deviceId);
                if (deviceIndex != -1) {
                  devices[deviceIndex] = allDevices[index];
                }
              });
            }
            print("Updated device $deviceId: ${allDevices[index]}");
          });
        }, onError: (error) {
          print("Error listening to device $deviceId: $error");
        });
      }
    } catch (e) {
      print("Error loading devices: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addDevice(String name, Map<String, dynamic> deviceData) {
    setState(() {
      if (!allDevices.any((d) => d['id'] == deviceData['id'])) {
        allDevices.add(deviceData);
        groupedDevices['Chưa phân khu'] = groupedDevices['Chưa phân khu'] ?? [];
        groupedDevices['Chưa phân khu']!.add(deviceData);

        // Cập nhật Firebase để thêm thiết bị với trạng thái true
        final user = _auth.currentUser;
        if (user != null) {
          _dbRef.child('users/${user.uid}/devices/${deviceData['id']}').set(true);
        }
      }
    });
    // Tải lại dữ liệu để đảm bảo đồng bộ
    _loadDevices();
  }

  void _addRegion(String regionName) {
    final user = _auth.currentUser;
    if (user != null) {
      final newRegionId = DateTime.now().millisecondsSinceEpoch.toString();
      _dbRef
          .child('users/${user.uid}/groups/$newRegionId')
          .set({
        'name': regionName,
        'devices': {},
      })
          .then((_) {
        setState(() {
          groupedDevices[regionName] = [];
        });
        // Tải lại dữ liệu để đảm bảo đồng bộ
        _loadDevices();
      })
          .catchError((error) {
        print("Error adding region: $error");
      });
    }
  }

  void _addDeviceToRegion(String regionName, String deviceId) {
    final user = _auth.currentUser;
    if (user != null) {
      _dbRef.child('users/${user.uid}/groups').once().then((snapshot) {
        final groupsData = snapshot.snapshot.value as Map<dynamic, dynamic>? ?? {};
        String? targetGroupId;
        groupsData.forEach((groupId, groupData) {
          if (groupData['name'] == regionName) {
            targetGroupId = groupId;
          }
        });

        if (targetGroupId != null) {
          _dbRef
              .child('users/${user.uid}/groups/$targetGroupId/devices/$deviceId')
              .set(true)
              .then((_) {
            setState(() {
              final device = allDevices.firstWhere(
                    (d) => d['id'] == deviceId,
                orElse: () => <String, dynamic>{},
              );
              if (device.isNotEmpty) {
                groupedDevices['Chưa phân khu']?.removeWhere((d) => d['id'] == deviceId);
                groupedDevices[regionName] = groupedDevices[regionName] ?? [];
                groupedDevices[regionName]!.add(device);
              } else {
                print("Device with ID $deviceId not found in allDevices");
              }
            });
            // Tải lại dữ liệu để đảm bảo đồng bộ
            _loadDevices();
          }).catchError((error) {
            print("Error adding device to region: $error");
          });
        }
      }).catchError((error) {
        print("Error fetching groups: $error");
      });
    }
  }

  void _removeDeviceFromRegion(String regionName, String deviceId) {
    final user = _auth.currentUser;
    if (user != null) {
      _dbRef.child('users/${user.uid}/groups').once().then((snapshot) {
        final groupsData = snapshot.snapshot.value as Map<dynamic, dynamic>? ?? {};
        String? targetGroupId;
        groupsData.forEach((groupId, groupData) {
          if (groupData['name'] == regionName) {
            targetGroupId = groupId;
          }
        });

        if (targetGroupId != null) {
          _dbRef
              .child('users/${user.uid}/groups/$targetGroupId/devices/$deviceId')
              .remove()
              .then((_) {
            setState(() {
              groupedDevices[regionName]?.removeWhere((d) => d['id'] == deviceId);
            });
            _loadDevices();
          }).catchError((error) {
            print("Error removing device from region: $error");
          });
        }
      }).catchError((error) {
        print("Error fetching groups: $error");
      });
    }
  }

  void _removeRegion(String regionName) {
    final user = _auth.currentUser;
    if (user != null) {
      _dbRef.child('users/${user.uid}/groups').once().then((snapshot) {
        final groupsData = snapshot.snapshot.value as Map<dynamic, dynamic>? ?? {};
        String? targetGroupId;
        groupsData.forEach((groupId, groupData) {
          if (groupData['name'] == regionName) {
            targetGroupId = groupId;
          }
        });

        if (targetGroupId != null) {
          _dbRef
              .child('users/${user.uid}/groups/$targetGroupId')
              .remove()
              .then((_) {
            setState(() {
              final devicesToMove = groupedDevices[regionName] ?? [];
              groupedDevices.remove(regionName);
              groupedDevices['Chưa phân khu'] = groupedDevices['Chưa phân khu'] ?? [];
              groupedDevices['Chưa phân khu']!.addAll(devicesToMove);
            });
            _loadDevices();
          }).catchError((error) {
            print("Error removing region: $error");
          });
        }
      }).catchError((error) {
        print("Error fetching groups: $error");
      });
    }
  }

  void _showAddRegionDialog() {
    final TextEditingController _regionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Thêm khu vực mới"),
        content: TextField(
          controller: _regionController,
          decoration: const InputDecoration(labelText: "Tên khu vực"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () {
              if (_regionController.text.isNotEmpty) {
                _addRegion(_regionController.text);
                Navigator.pop(context);
              }
            },
            child: const Text("Thêm"),
          ),
        ],
      ),
    );
  }

  void _showAddDeviceToRegionDialog(String regionName) {
    if (allDevices.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Thông báo"),
          content: const Text("Không có thiết bị nào để thêm. Vui lòng thêm thiết bị trước."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Đóng"),
            ),
          ],
        ),
      );
      return;
    }

    String? selectedDeviceId;
    final assignedDeviceIds = groupedDevices.entries
        .where((entry) => entry.key != 'Chưa phân khu')
        .expand((entry) => entry.value.map((device) => device['id']))
        .toSet();

    final availableDevices = allDevices.where((device) => !assignedDeviceIds.contains(device['id'])).toList();
    print("Available devices for $regionName: $availableDevices");
    print("Assigned device IDs: $assignedDeviceIds");

    if (availableDevices.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Thông báo"),
          content: const Text("Tất cả thiết bị đã được gán. Vui lòng thêm thiết bị mới."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Đóng"),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Thêm thiết bị vào $regionName"),
        content: StatefulBuilder(
          builder: (context, setState) => DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: "Chọn thiết bị"),
            items: availableDevices.map((device) {
              return DropdownMenuItem<String>(
                value: device['id'],
                child: Text(device['name'] ?? 'Unnamed Device'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedDeviceId = value;
              });
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () {
              if (selectedDeviceId != null) {
                _addDeviceToRegion(regionName, selectedDeviceId!);
                Navigator.pop(context);
              }
            },
            child: const Text("Thêm"),
          ),
        ],
      ),
    );
  }

  String _getMotorStatus(dynamic status) {
    final statusStr = status?.toString().toLowerCase() ?? '';
    print("Processing motor status in MicroPage: $status (type: ${status.runtimeType})");
    if (status == 1 || statusStr == '1' || statusStr == 'bật' || statusStr == 'on' || status == true) {
      return "Bật";
    }
    if (status == 0 || statusStr == '0' || statusStr == 'tắt' || statusStr == 'off' || status == false) {
      return "Tắt";
    }
    if (status == 20 || statusStr == '20') return "Tự động (Tắt)";
    if (status == 21 || statusStr == '21') return "Tự động (Bật)";
    return "Không xác định";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _showAddRegionDialog,
            backgroundColor: const Color.fromRGBO(0, 100, 53, 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            child: const Icon(Icons.map, color: Colors.white, size: 32),
            heroTag: "addRegion",
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddGardenPage(onAddDevice: _addDevice),
                ),
              );
            },
            backgroundColor: const Color.fromRGBO(0, 100, 53, 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            child: const Icon(Icons.add, color: Colors.white, size: 32),
            heroTag: "addDevice",
          ),
        ],
      ),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Smart Garden",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 25,
            ),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  height: 80,
                  decoration: const BoxDecoration(
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    "Ground Sensors",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      height: 0.9,
                      fontWeight: FontWeight.w600,
                      fontSize: 28,
                      shadows: [
                        const Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (groupedDevices.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "No devices available",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ),
              )
            else
              ...groupedDevices.entries
                  .where((entry) =>
              entry.key != 'Chưa phân khu' || entry.value.isNotEmpty)
                  .map((entry) {
                final regionName = entry.key;
                final devicesInRegion = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                regionName,
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: const Color.fromRGBO(0, 100, 53, 1),
                                ),
                              ),
                              if (regionName != 'Chưa phân khu')
                                IconButton(
                                  icon: const Icon(Icons.bar_chart,
                                      color: Colors.blue),
                                  tooltip: 'Tổng quan khu vực',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => OverviewPage(
                                          regionName: regionName,
                                          devices: devicesInRegion,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              if (regionName != 'Chưa phân khu')
                                IconButton(
                                  icon: const Icon(Icons.add_circle,
                                      color: Colors.green),
                                  onPressed: () =>
                                      _showAddDeviceToRegionDialog(regionName),
                                ),
                              if (regionName != 'Chưa phân khu')
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _removeRegion(regionName),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (devicesInRegion.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text(
                          "No devices in this region",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    else
                      ...devicesInRegion.map((device) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 10),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NodeDetails(device: device),
                                ),
                              );
                            },
                            child: Container(
                              height: 120,
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20.0, vertical: 10),
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          device['name'],
                                          style: GoogleFonts.poppins(
                                            color: const Color.fromRGBO(
                                                0, 100, 53, 1),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 20,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          "Soil: ${device['doAmDat']?['current'] ?? 'N/A'}%",
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          "Máy bơm: ${_getMotorStatus(device['mayBom']?['trangThai'])}",
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        if (regionName != 'Chưa phân khu')
                                          IconButton(
                                            icon: const Icon(
                                                Icons.remove_circle,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _removeDeviceFromRegion(
                                                    regionName, device['id']),
                                          ),
                                        Container(
                                          height: 60,
                                          width: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                            BorderRadius.circular(30),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey
                                                    .withOpacity(0.2),
                                                spreadRadius: 1,
                                                blurRadius: 3,
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                            BorderRadius.circular(30),
                                            child: Image.asset(
                                                'lib/images/plant.png',
                                                fit: BoxFit.cover),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}