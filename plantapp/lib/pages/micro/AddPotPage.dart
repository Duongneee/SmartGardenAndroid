import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AddGardenPage extends StatefulWidget {
  final Function(String, Map<String, dynamic>) onAddDevice; // Changed from onAddGarden

  const AddGardenPage({Key? key, required this.onAddDevice}) : super(key: key);

  @override
  State<AddGardenPage> createState() => _AddGardenPageState();
}

class _AddGardenPageState extends State<AddGardenPage> {
  final TextEditingController _keyController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  bool _isLoading = false;

  void _handleSave() async {
    setState(() => _isLoading = true);
    final user = _auth.currentUser;

    if (user == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập.')),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final userId = user.uid;
    final key = _keyController.text.trim();

    try {
      // Kiểm tra key trong node keys
      final keySnap = await _dbRef.child('keys/$key').get();

      if (!keySnap.exists) {
        _showError('Key không hợp lệ hoặc không tồn tại.');
        return;
      }

      final deviceId = keySnap.value as String; // Changed from gardenId

      // Kiểm tra xem thiết bị đã được thêm bởi người dùng khác chưa
      final usersSnap = await _dbRef.child('users').get();
      bool isTaken = false;

      if (usersSnap.exists) {
        final users = usersSnap.value as Map;
        for (final uid in users.keys) {
          final groups = users[uid]['groups'];
          if (groups != null) {
            for (final group in groups.values) {
              if (group['devices'] != null && group['devices'][deviceId] == true) { // Changed from gardens
                isTaken = true;
                break;
              }
            }
          }
        }
      }

      if (isTaken) {
        _showError('Thiết bị này đã được thêm bởi người dùng khác.'); // Changed from Khu vườn
        return;
      }

      // Kiểm tra thiết bị trong danh sách của người dùng hiện tại
      bool deviceExists = false;
      final userGroupsSnap = await _dbRef.child('users/$userId/groups').get();
      if (userGroupsSnap.exists) {
        final groups = userGroupsSnap.value as Map;
        for (final groupId in groups.keys) {
          final devices = groups[groupId]['devices'];
          if (devices != null && devices[deviceId] == true) {
            deviceExists = true;
            break;
          } else if (devices != null && devices[deviceId] == false) {
            // Kích hoạt lại thiết bị
            await _dbRef.child('users/$userId/groups/$groupId/devices/$deviceId').set(true);
            _showSuccess('Thiết bị đã được kích hoạt lại thành công!'); // Changed from Khu vườn
            _updateCallback(deviceId);
            return;
          }
        }
      }

      if (deviceExists) {
        _showError('Thiết bị đã tồn tại trong danh sách của bạn.'); // Changed from Khu vườn
      } else {
        // Thêm thiết bị mới (giả định thêm vào group mặc định, ví dụ groupId là 'default')
        await _dbRef.child('users/$userId/devices/$deviceId').set(true); // Thêm vào group mặc định
        _showSuccess('Thiết bị đã được thêm thành công!'); // Changed from Khu vườn
        _updateCallback(deviceId);
      }
    } catch (e) {
      _showError('Có lỗi xảy ra: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateCallback(String deviceId) async {
    final deviceSnap = await _dbRef.child('devices/$deviceId').get();
    final deviceData = deviceSnap.exists ? deviceSnap.value as Map : {'id': deviceId, 'name': 'Thiết bị Mới'}; // Changed from Khu Vườn Mới

    widget.onAddDevice(deviceData['name'] ?? 'Thiết bị Mới', { // Changed from onAddGarden
      'id': deviceId,
      'name': deviceData['name'] ?? 'Thiết bị Mới', // Changed from Khu Vườn Mới
    });

    Navigator.pop(context);
  }

  void _showError(String message) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm Thiết bị'), // Changed from Thêm Khu Vườn
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Nhập Key Thiết bị', // Changed from Nhập Key Khu Vườn
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _keyController,
                    decoration: InputDecoration(
                      labelText: 'Key',
                      labelStyle: TextStyle(color: Colors.green),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.vpn_key, color: Colors.green),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleSave,
                    icon: const Icon(Icons.save),
                    label: Text(_isLoading ? 'Đang xử lý...' : 'Lưu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      shadowColor: Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Trở về danh sách'),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}