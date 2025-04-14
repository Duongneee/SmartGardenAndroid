import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:plantapp/pages/micro/NodeDetails.dart';
import 'package:plantapp/pages/micro/AddPotPage.dart';

class MicroPage extends StatefulWidget {
  const MicroPage({super.key});

  @override
  _MicroPageState createState() => _MicroPageState();
}

class _MicroPageState extends State<MicroPage> {
  Map<String, List<Map<String, dynamic>>> groupedGardens = {};
  List<Map<String, dynamic>> allGardens = [];
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadGardens();
  }

  void _loadGardens() {
    _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        print("User not logged in");
        setState(() {
          groupedGardens = {};
          allGardens = [];
        });
        return;
      }

      final userGardensRef = _dbRef.child('users/${user.uid}/gardens');
      userGardensRef.onValue.listen((event) {
        final userGardenData = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
        final userGardenIds = userGardenData.keys.toList();

        final gardensRef = _dbRef.child('gardens');
        gardensRef.onValue.listen((gardenEvent) {
          final allGardensData = gardenEvent.snapshot.value as Map<dynamic, dynamic>? ?? {};
          allGardens = userGardenIds
              .where((id) => allGardensData[id] != null)
              .map((id) => {
            'id': id,
            ...Map<String, dynamic>.from(allGardensData[id] as Map),
          })
              .toList();

          final groupsRef = _dbRef.child('users/${user.uid}/groups');
          groupsRef.onValue.listen((groupEvent) {
            final groupsData = groupEvent.snapshot.value as Map<dynamic, dynamic>? ?? {};
            final Map<String, List<Map<String, dynamic>>> tempGroupedGardens = {
              'Chưa phân khu': [],
            };

            groupsData.forEach((groupId, groupData) {
              final groupName = groupData['name'] as String? ?? 'Unnamed Group';
              tempGroupedGardens[groupName] = [];
            });

            for (var garden in allGardens) {
              bool assigned = false;
              groupsData.forEach((groupId, groupData) {
                final groupName = groupData['name'] as String? ?? 'Unnamed Group';
                final groupGardens = (groupData['gardens'] as Map<dynamic, dynamic>?) ?? {};
                if (groupGardens.containsKey(garden['id'])) {
                  tempGroupedGardens[groupName]!.add(garden);
                  assigned = true;
                }
              });
              if (!assigned) {
                tempGroupedGardens['Chưa phân khu']!.add(garden);
              }
            }

            setState(() {
              groupedGardens = tempGroupedGardens;
            });
          });
        });
      });
    });
  }

  void _addPot(String name, Map<String, dynamic> gardenData) {
    setState(() {
      gardenData['id'] = _dbRef.child('gardens').push().key;
      allGardens.add(gardenData);
      groupedGardens['Chưa phân khu'] = groupedGardens['Chưa phân khu'] ?? [];
      groupedGardens['Chưa phân khu']!.add(gardenData);
    });

    final user = _auth.currentUser;
    if (user != null) {
      final newGardenId = gardenData['id'];
      _dbRef.child('gardens/$newGardenId').set(gardenData);
      _dbRef.child('users/${user.uid}/gardens/$newGardenId').set(true);
    }
  }

  void _addRegion(String regionName) {
    final user = _auth.currentUser;
    if (user != null) {
      final newRegionId = DateTime.now().millisecondsSinceEpoch.toString();
      _dbRef.child('users/${user.uid}/groups/$newRegionId').set({
        'name': regionName,
        'gardens': {},
      });
      setState(() {
        groupedGardens[regionName] = [];
      });
    }
  }

  void _addGardenToRegion(String regionName, String gardenId) {
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
          _dbRef.child('users/${user.uid}/groups/$targetGroupId/gardens/$gardenId').set(true);

          setState(() {
            final garden = allGardens.firstWhere((g) => g['id'] == gardenId);
            groupedGardens['Chưa phân khu']?.removeWhere((g) => g['id'] == gardenId);
            groupedGardens[regionName] = groupedGardens[regionName] ?? [];
            groupedGardens[regionName]!.add(garden);
          });
        }
      });
    }
  }

  void _removeGardenFromRegion(String regionName, String gardenId) {
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
          _dbRef.child('users/${user.uid}/groups/$targetGroupId/gardens/$gardenId').remove();

          setState(() {
            final garden = groupedGardens[regionName]!.firstWhere((g) => g['id'] == gardenId);
            groupedGardens[regionName]!.removeWhere((g) => g['id'] == gardenId);
            groupedGardens['Chưa phân khu'] = groupedGardens['Chưa phân khu'] ?? [];
            groupedGardens['Chưa phân khu']!.add(garden);
          });
        }
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
          _dbRef.child('users/${user.uid}/groups/$targetGroupId').remove();

          setState(() {
            final gardensToMove = groupedGardens[regionName]!;
            groupedGardens.remove(regionName);
            groupedGardens['Chưa phân khu'] = groupedGardens['Chưa phân khu'] ?? [];
            groupedGardens['Chưa phân khu']!.addAll(gardensToMove);
          });
        }
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

  void _showAddGardenToRegionDialog(String regionName) {
    String? selectedGardenId;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Thêm khu vườn vào $regionName"),
        content: StatefulBuilder(
          builder: (context, setState) => DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: "Chọn khu vườn"),
            items: groupedGardens['Chưa phân khu']?.map((garden) {
              return DropdownMenuItem<String>(
                value: garden['id'],
                child: Text(garden['name']),
              );
            }).toList() ?? [],
            onChanged: (value) {
              setState(() {
                selectedGardenId = value;
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
              if (selectedGardenId != null) {
                _addGardenToRegion(regionName, selectedGardenId!);
                Navigator.pop(context);
              }
            },
            child: const Text("Thêm"),
          ),
        ],
      ),
    );
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
                  builder: (context) => AddPotPage(onAddPot: _addPot),
                ),
              );
            },
            backgroundColor: const Color.fromRGBO(0, 100, 53, 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            child: const Icon(Icons.add, color: Colors.white, size: 32),
            heroTag: "addGarden",
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
        child: ListView(
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
                      shadows: [const Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (groupedGardens.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("No gardens available", style: TextStyle(fontSize: 18, color: Colors.grey)),
                ),
              )
            else
              ...groupedGardens.entries
                  .where((entry) => entry.key != 'Chưa phân khu' || entry.value.isNotEmpty)
                  .map((entry) {
                final regionName = entry.key;
                final gardensInRegion = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            regionName,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: const Color.fromRGBO(0, 100, 53, 1),
                            ),
                          ),
                          Row(
                            children: [
                              if (regionName != 'Chưa phân khu')
                                IconButton(
                                  icon: const Icon(Icons.add_circle, color: Colors.green),
                                  onPressed: () => _showAddGardenToRegionDialog(regionName),
                                ),
                              if (regionName != 'Chưa phân khu')
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeRegion(regionName),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (gardensInRegion.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text("No gardens in this region", style: TextStyle(fontSize: 16, color: Colors.grey)),
                      )
                    else
                      ...gardensInRegion.map((garden) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NodeDetails(garden: garden),
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
                                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          garden['name'],
                                          style: GoogleFonts.poppins(
                                            color: const Color.fromRGBO(0, 100, 53, 1),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 20,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          "Soil: ${garden['doAmDat']?['current'] ?? 'N/A'}%",
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          "Max: ${garden['doAmDat']?['max'] ?? 'N/A'}%",
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          "Min: ${garden['doAmDat']?['min'] ?? 'N/A'}%",
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
                                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                                            onPressed: () => _removeGardenFromRegion(regionName, garden['id']),
                                          ),
                                        Container(
                                          height: 60,
                                          width: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(30),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(0.2),
                                                spreadRadius: 1,
                                                blurRadius: 3,
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(30),
                                            child: Image.asset('lib/images/plant.png', fit: BoxFit.cover),
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