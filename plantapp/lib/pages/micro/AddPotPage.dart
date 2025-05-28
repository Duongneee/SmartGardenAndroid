import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AddGardenPage extends StatefulWidget {
  final Function(String, Map<String, dynamic>) onAddGarden;

  const AddGardenPage({Key? key, required this.onAddGarden}) : super(key: key);

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

      final gardenId = keySnap.value as String;

      // Kiểm tra xem khu vườn đã được thêm bởi người dùng khác chưa
      final usersSnap = await _dbRef.child('users').get();
      bool isTaken = false;

      if (usersSnap.exists) {
        final users = usersSnap.value as Map;
        for (final uid in users.keys) {
          final gardens = users[uid]['gardens'];
          if (gardens != null && gardens[gardenId] == true) {
            isTaken = true;
            break;
          }
        }
      }

      if (isTaken) {
        _showError('Khu vườn này đã được thêm bởi người dùng khác.');
        return;
      }

      // Kiểm tra khu vườn trong danh sách của người dùng hiện tại
      final userGardenSnap = await _dbRef.child('users/$userId/gardens/$gardenId').get();

      if (userGardenSnap.exists) {
        final status = userGardenSnap.value;
        if (status == true) {
          _showError('Khu vườn đã tồn tại trong danh sách của bạn.');
        } else if (status == false) {
          // Kích hoạt lại khu vườn
          await _dbRef.child('users/$userId/gardens/$gardenId').set(true);
          _showSuccess('Khu vườn đã được kích hoạt lại thành công!');
        }
      } else {
        // Thêm khu vườn mới
        await _dbRef.child('users/$userId/gardens/$gardenId').set(true);
        _showSuccess('Khu vườn đã được thêm thành công!');
      }

      // Lấy thông tin khu vườn để truyền qua callback
      final gardenSnap = await _dbRef.child('gardens/$gardenId').get();
      final gardenData = gardenSnap.exists ? gardenSnap.value as Map : {'id': gardenId, 'name': 'Khu Vườn Mới'};

      // Gọi callback để cập nhật danh sách bên ngoài
      widget.onAddGarden(gardenData['name'] ?? 'Khu Vườn Mới', {
        'id': gardenId,
        'name': gardenData['name'] ?? 'Khu Vườn Mới',
      });

      Navigator.pop(context);
    } catch (e) {
      _showError('Có lỗi xảy ra: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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
        title: const Text('Thêm Khu Vườn'),
        backgroundColor: Colors.green, // Màu xanh lá cây cho AppBar
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 10, // Tăng bóng đổ để nổi bật hơn
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Nhập Key Khu Vườn',
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
                      backgroundColor: Colors.green, // Màu xanh lá cây cho nút lưu
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      shadowColor: Colors.greenAccent, // Bóng đổ sáng màu
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Trở về danh sách'),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.green, // Màu xanh lá cây cho nút quay lại
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      foregroundColor: Colors.white, // Màu chữ trắng
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