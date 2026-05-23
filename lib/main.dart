import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await availableCameras();
  } catch (e) {
    debugPrint("Kamera error: $e");
  }
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
      home: const AuthPage(),
    ),
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  bool _obscurePassword = true;
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  String? _tempFacePath;

  void _submit() async {
    String user = _userController.text.trim();
    String pass = _passController.text.trim();
    if (user.isEmpty || pass.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    if (isLogin) {
      String? savedPass = prefs.getString("pwd_$user");
      if (savedPass != null && savedPass == pass) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => DashboardTabs(userName: user)),
        );
      } else {
        _msg("Username atau Password salah!");
      }
    } else {
      if (_tempFacePath == null) {
        _msg("Wajib Verifikasi Wajah saat Pendaftaran!");
        return;
      }
      await prefs.setString("pwd_$user", pass);
      await prefs.setString("face_$user", _tempFacePath!);
      _msg("Daftar Berhasil! Silahkan Login");
      setState(() {
        isLogin = true;
        _userController.clear();
        _passController.clear();
      });
    }
  }

  void _msg(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              Icon(
                isLogin ? Icons.lock_person : Icons.assignment_ind,
                size: 80,
                color: Colors.teal,
              ),
              const SizedBox(height: 10),
              Text(
                isLogin ? "Portal Login Karyawan" : "Registrasi Akun & Wajah",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _userController,
                decoration: const InputDecoration(
                  labelText: "Username / ID Karyawan",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.teal,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              if (!isLogin) ...[
                const SizedBox(height: 25),
                const Text("Ambil Foto Wajah Master (Registrasi):"),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final cams = await availableCameras();
                    if (!mounted) return;
                    final XFile? photo = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) =>
                            CameraPage(cameras: cams, title: "Foto Registrasi"),
                      ),
                    );
                    if (photo != null)
                      setState(() => _tempFacePath = photo.path);
                  },
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.teal[50],
                    child: _tempFacePath == null
                        ? const Icon(Icons.add_a_photo, color: Colors.teal)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.file(
                              File(_tempFacePath!),
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
              ],
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                child: Text(isLogin ? "MASUK" : "DAFTAR AKUN"),
              ),
              TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: Text(
                  isLogin
                      ? "Belum terdaftar? Buat Akun"
                      : "Sudah punya akun? Login",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardTabs extends StatelessWidget {
  final String userName;
  const DashboardTabs({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        bottomNavigationBar: const Material(
          color: Colors.teal,
          child: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.tealAccent,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.fingerprint), text: "Absen"),
              Tab(icon: Icon(Icons.mail), text: "Izin/Cuti"),
              Tab(icon: Icon(Icons.history), text: "Riwayat"),
              Tab(icon: Icon(Icons.person), text: "Laporan"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            BerandaPage(userName: userName),
            IzinCutiPage(userName: userName),
            HistoryPage(userName: userName),
            LaporanPribadiPage(userName: userName),
          ],
        ),
      ),
    );
  }
}

class BerandaPage extends StatefulWidget {
  final String userName;
  const BerandaPage({super.key, required this.userName});
  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  bool _loadingLokasi = true;
  bool _isMocked = false;
  String _waktuMasuk = "-";
  String _imgMasuk = "";
  String _ketMasuk = "";
  String _waktuPulang = "-";
  String _imgPulang = "";
  String _ketPulang = "";

  @override
  void initState() {
    super.initState();
    _loadDataAbsensi();
    _initLokasiFleksibel();
    _triggerNotification();
  }

  void _triggerNotification() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.amber,
          duration: Duration(seconds: 4),
          content: Row(
            children: [
              Icon(Icons.add_alert, color: Colors.black),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Pengingat: Jangan lupa lakukan Absen Pulang sebelum jam 17:00 WIB!",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _loadDataAbsensi() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _waktuMasuk = prefs.getString("in_time_${widget.userName}") ?? "-";
      _imgMasuk = prefs.getString("in_img_${widget.userName}") ?? "";
      _ketMasuk = prefs.getString("in_ket_${widget.userName}") ?? "";
      _waktuPulang = prefs.getString("out_time_${widget.userName}") ?? "-";
      _imgPulang = prefs.getString("out_img_${widget.userName}") ?? "";
      _ketPulang = prefs.getString("out_ket_${widget.userName}") ?? "";
    });
  }

  Future<void> _initLokasiFleksibel() async {
    if (!mounted) return;
    setState(() => _loadingLokasi = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _isMocked = pos.isMocked;
        _loadingLokasi = false;
      });
    } catch (e) {
      debugPrint("Gagal mengunci GPS fleksibel: $e");
      setState(() => _loadingLokasi = false);
    }
  }

  void _prosesAbsen(String tipe) async {
    if (_isMocked) {
      _showDialogAlert(
        "Peringatan Keamanan",
        "Fake GPS terdeteksi! Absensi ditolak oleh sistem keamanan.",
      );
      return;
    }
    final cams = await availableCameras();
    if (!mounted) return;

    final Map<String, dynamic>? hasilKamera = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => CameraPage(
          cameras: cams,
          title: "Verifikasi Wajah",
          isVerificationMode: true,
        ),
      ),
    );

    if (hasilKamera != null) {
      bool wajahCocok = hasilKamera['wajahCocok'] ?? true;
      if (!wajahCocok) {
        _showDialogAlert(
          "Verifikasi Gagal ❌",
          "Sistem mendeteksi wajah tidak cocok dengan data master terdaftar. Absensi ditolak!",
        );
        return;
      }
      _loadingSimulasi(hasilKamera['path'], tipe);
    }
  }

  void _loadingSimulasi(String pathBaru, String tipe) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        Future.delayed(const Duration(seconds: 2), () async {
          if (!mounted) return;
          Navigator.pop(context);

          String jamSkrg = DateFormat('HH:mm:ss').format(DateTime.now());
          String tglSkrg = DateFormat('dd MMM yyyy').format(DateTime.now());

          final prefs = await SharedPreferences.getInstance();
          List<dynamic> historyList = [];
          String? historyRaw = prefs.getString("history_${widget.userName}");
          if (historyRaw != null) historyList = jsonDecode(historyRaw);

          if (tipe == "masuk") {
            setState(() {
              _waktuMasuk = jamSkrg;
              _imgMasuk = pathBaru;
              _ketMasuk = "Area Kerja Kelapa Gading (0m)";
            });
            await prefs.setString("in_time_${widget.userName}", _waktuMasuk);
            await prefs.setString("in_img_${widget.userName}", _imgMasuk);
            await prefs.setString("in_ket_${widget.userName}", _ketMasuk);

            _showDialogAlert(
              "Status Absensi",
              "Absen MASUK BERHASIL.\nWaktu: $jamSkrg",
            );
          } else {
            Map<String, String> historyItem = {
              "tanggal": tglSkrg,
              "masuk": _waktuMasuk,
              "pulang": jamSkrg,
              "ket": "Area Kerja Kelapa Gading (0m)",
              "status_absen": "Sukses",
            };
            historyList.insert(0, historyItem);
            await prefs.setString(
              "history_${widget.userName}",
              jsonEncode(historyList),
            );

            await prefs.remove("in_time_${widget.userName}");
            await prefs.remove("in_img_${widget.userName}");
            await prefs.remove("in_ket_${widget.userName}");

            setState(() {
              _waktuMasuk = "-";
              _imgMasuk = "";
              _ketMasuk = "";
              _waktuPulang = "-";
              _imgPulang = "";
              _ketPulang = "";
            });

            _showDialogAlert(
              "Status Absensi",
              "Absen PULANG BERHASIL.\nData hari ini sukses masuk ke Tab Riwayat (History).\n\nSistem di-reset! Anda bisa langsung mencoba simulasi absensi lagi sekarang.",
            );
          }
        });
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 15),
              Text("Validasi Wajah & Geofencing..."),
            ],
          ),
        );
      },
    );
  }

  void _showDialogAlert(String t, String c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t),
        content: Text(c),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Apakah Anda yakin ingin keluar dari akun ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (ctx) => const AuthPage()),
              );
            },
            child: const Text(
              "Ya, Keluar",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Karyawan: ${widget.userName}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            color: _isMocked ? Colors.purple[50] : Colors.green[50],
            child: Center(
              child: _loadingLokasi
                  ? const Text("Mengunci Koordinat Kerja...")
                  : Text(
                      _isMocked
                          ? "⚠️ Fake GPS Terdeteksi!"
                          : "Status Lokasi: Di Area Kerja Kelapa Gading (0.00 KM)",
                    ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statusCard(
                        "Masuk",
                        _waktuMasuk,
                        _imgMasuk,
                        _ketMasuk,
                        Colors.green,
                      ),
                      _statusCard(
                        "Pulang",
                        _waktuPulang,
                        _imgPulang,
                        _ketPulang,
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: _loadingLokasi
                        ? null
                        : () => _prosesAbsen(
                            _waktuMasuk == "-" ? "masuk" : "pulang",
                          ),
                    icon: const Icon(Icons.camera_alt),
                    label: Text(
                      _waktuMasuk == "-"
                          ? "ABSEN MASUK (SELFIE)"
                          : "ABSEN PULANG (SELFIE)",
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 65),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(
    String title,
    String waktu,
    String imgPath,
    String ket,
    Color col,
  ) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: col),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.teal.shade100),
          ),
          child: imgPath.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(File(imgPath), fit: BoxFit.cover),
                )
              : const Icon(Icons.no_photography, color: Colors.grey),
        ),
        const SizedBox(height: 5),
        Text(
          waktu,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (ket.isNotEmpty)
          Text(
            ket,
            style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
          ),
      ],
    );
  }
}

class IzinCutiPage extends StatefulWidget {
  final String userName;
  const IzinCutiPage({super.key, required this.userName});
  @override
  State<IzinCutiPage> createState() => _IzinCutiPageState();
}

class _IzinCutiPageState extends State<IzinCutiPage> {
  final _alasanController = TextEditingController();
  String _jenisPengajuan = 'Izin';
  List<dynamic> _izinList = [];

  @override
  void initState() {
    super.initState();
    _loadDataIzin();
  }

  Future<void> _loadDataIzin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      String? raw = prefs.getString("izin_${widget.userName}");
      if (raw != null) _izinList = jsonDecode(raw);
    });
  }

  void _kirimPengajuan() async {
    if (_alasanController.text.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();

    Map<String, String> newItem = {
      "jenis": _jenisPengajuan,
      "tanggal": DateFormat('dd MMM yyyy').format(DateTime.now()),
      "alasan": _alasanController.text,
      "status": "Menunggu Approval",
    };

    setState(() {
      _izinList.insert(0, newItem);
      _alasanController.clear();
    });

    await prefs.setString("izin_${widget.userName}", jsonEncode(_izinList));
    _msgSuccess();
  }

  void _msgSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Text("Pengajuan Berhasil Dikirim ke HRD!"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Form Pengajuan Izin/Cuti")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _jenisPengajuan,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Jenis Pengajuan",
              ),
              items: [
                'Izin',
                'Sakit',
                'Cuti',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _jenisPengajuan = v!),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _alasanController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Keterangan/Alasan",
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: _kirimPengajuan,
              icon: const Icon(Icons.send),
              label: const Text("KIRIM KE HRD (ONLINE)"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              "Histori Pengajuan Dokumen:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Expanded(
              child: _izinList.isEmpty
                  ? const Center(child: Text("Belum ada histori pengajuan."))
                  : ListView.builder(
                      itemCount: _izinList.length,
                      itemBuilder: (c, i) {
                        var item = _izinList[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.file_present,
                              color: Colors.orange,
                            ),
                            title: Text(
                              "${item['jenis']} - ${item['tanggal']}",
                            ),
                            subtitle: Text("Alasan: ${item['alasan']}"),
                            trailing: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.amber[100],
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                item['status'],
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
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
    );
  }
}

class HistoryPage extends StatefulWidget {
  final String userName;
  const HistoryPage({super.key, required this.userName});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<dynamic> _historyList = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      String? raw = prefs.getString("history_${widget.userName}");
      if (raw != null) _historyList = jsonDecode(raw);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Log Riwayat Presensi"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Fitur Download Laporan PDF Berhasil Diunduh! (Simulasi)",
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _historyList.isEmpty
          ? const Center(child: Text("Tidak ada catatan riwayat absensi."))
          : ListView.builder(
              itemCount: _historyList.length,
              itemBuilder: (context, index) {
                var item = _historyList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.check, color: Colors.white),
                    ),
                    title: Text("Tanggal: ${item['tanggal']}"),
                    subtitle: Text(
                      "Masuk: ${item['masuk']} | Pulang: ${item['pulang']}\nSistem Validasi: ${item['ket']}",
                    ),
                    trailing: const Text(
                      "DONE",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class LaporanPribadiPage extends StatefulWidget {
  final String userName;
  const LaporanPribadiPage({super.key, required this.userName});
  @override
  State<LaporanPribadiPage> createState() => _LaporanPribadiPageState();
}

class _LaporanPribadiPageState extends State<LaporanPribadiPage> {
  int totalHadir = 0;
  int totalIzin = 0;

  @override
  void initState() {
    super.initState();
    _hitungRangkuman();
  }

  Future<void> _hitungRangkuman() async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> hList = [];
    List<dynamic> iList = [];
    String? rawH = prefs.getString("history_${widget.userName}");
    String? rawI = prefs.getString("izin_${widget.userName}");
    if (rawH != null) hList = jsonDecode(rawH);
    if (rawI != null) iList = jsonDecode(rawI);
    setState(() {
      totalHadir = hList.length;
      totalIzin = iList.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rangkuman Laporan Bulanan"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _hitungRangkuman,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Icon(Icons.analytics, size: 70, color: Colors.teal),
            const SizedBox(height: 10),
            const Text(
              "Statistik Kehadiran Anda Bulan Ini",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                _statBox("TOTAL HADIR", totalHadir.toString(), Colors.teal),
                const SizedBox(width: 15),
                _statBox(
                  "TOTAL IZIN/CUTI",
                  totalIzin.toString(),
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 40),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text("Catatan Sistem"),
              subtitle: Text(
                "Data diperbarui secara otomatis berdasarkan rekaman GPS dan verifikasi wajah.",
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color col) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: col.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: col),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: col,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: col,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CameraPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String title;
  final bool isVerificationMode;
  const CameraPage({
    super.key,
    required this.cameras,
    required this.title,
    this.isVerificationMode = false,
  });
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) {
      var front = widget.cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => widget.cameras[0],
      );
      _controller = CameraController(front, ResolutionPreset.medium);
      _controller!.initialize().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: (_controller?.value.isInitialized ?? false)
                ? CameraPreview(_controller!)
                : const Center(child: CircularProgressIndicator()),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final img = await _controller?.takePicture();
                    if (mounted) {
                      Navigator.pop(context, {
                        'path': img?.path,
                        'wajahCocok': true,
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("AMBIL VERIFIKASI FOTO"),
                ),
                if (widget.isVerificationMode) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () async {
                      final img = await _controller?.takePicture();
                      if (mounted) {
                        Navigator.pop(context, {
                          'path': img?.path,
                          'wajahCocok': false,
                        });
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 45),
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                    ),
                    child: const Text("Simulasi: Gunakan Wajah Salah"),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
