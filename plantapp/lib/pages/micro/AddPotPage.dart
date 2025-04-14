import 'package:flutter/material.dart';
import 'package:plantapp/pages/models/Plant.dart';

class AddPotPage extends StatefulWidget {
  final void Function(String name, Map<String, dynamic> gardenData) onAddPot;

  const AddPotPage({super.key, required this.onAddPot});

  @override
  _AddPotPageState createState() => _AddPotPageState();
}

class _AddPotPageState extends State<AddPotPage> {
  final TextEditingController _nameController = TextEditingController();
  Plant? selectedPlant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New Garden"),
        backgroundColor: const Color.fromRGBO(161, 207, 107, 1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Garden Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<Plant>(
              decoration: const InputDecoration(
                labelText: "Select Plant",
                border: OutlineInputBorder(),
              ),
              items: plants
                  .map(
                    (plant) => DropdownMenuItem(
                  value: plant,
                  child: Text(plant.name),
                ),
              )
                  .toList(),
              onChanged: (Plant? plant) {
                setState(() {
                  selectedPlant = plant;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(74, 173, 82, 1),
              ),
              onPressed: () {
                if (_nameController.text.isNotEmpty && selectedPlant != null) {
                  // Tạo Map dữ liệu khu vườn từ thông tin nhập vào
                  final gardenData = {
                    'id': DateTime.now().millisecondsSinceEpoch.toString(), // ID tạm thời
                    'name': _nameController.text,
                    'doAmDat': {
                      'current': 0, // Giá trị mặc định
                      //'min': selectedPlant!.minSoilMoisture ?? 70,
                     // 'max': selectedPlant!.maxSoilMoisture ?? 95,
                    },
                    'mayBom': {'trangThai': 'Tắt'},
                    'plantInfo': {
                      'name': selectedPlant!.name,
                      'imageUrl': selectedPlant!.imageUrl,
                      // Thêm các thuộc tính khác của Plant nếu cần
                    },
                  };
                  widget.onAddPot(_nameController.text, gardenData);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Vui lòng điền đầy đủ thông tin"),
                    ),
                  );
                }
              },
              child: const Text("Add Garden"),
            ),
          ],
        ),
      ),
    );
  }
}