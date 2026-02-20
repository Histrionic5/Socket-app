import 'package:flutter/material.dart';
import 'loginPage.dart';
import 'Dashboard.dart';
import 'main.dart';
import 'package:my_wife/Database/LocalDatabase.dart';
import 'package:shared_preferences/shared_preferences.dart';

////////////////////////////////////////////////////////////////////////////////
// SETTINGS PAGE
////////////////////////////////////////////////////////////////////////////////

class SettingsPage extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  final bool notificationSound;
  final bool notificationVibration;
  final Function(bool) onSoundChanged;
  final Function(bool) onVibrationChanged;

  final int userId;
  final String username;
  final String email;

  const SettingsPage({
    Key? key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.notificationSound,
    required this.notificationVibration,
    required this.onSoundChanged,
    required this.onVibrationChanged,
    required this.userId,
    required this.username,
    required this.email,
  }) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _username;
  late String _email;

  @override
  void initState() {
    super.initState();
    _username = widget.username;
    _email = widget.email;
  }

  Future<void> _refreshUser() async {
    final user = await LocalDatabase.getUserById(widget.userId);
    if (user != null) {
      setState(() {
        _username = user["username"] ?? _username;
        _email = user["email"] ?? _email;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User info refreshed.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not found locally.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: RefreshIndicator(
        onRefresh: _refreshUser,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Profile Section
            Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundImage: AssetImage("assets/profile_pic.png"),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_username,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_email, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Settings Tiles
            _settingsTile(
              icon: Icons.power,
              title: "Sockets",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _SocketsPage()),
              ),
            ),
            _settingsTile(
              icon: Icons.notifications,
              title: "Notifications",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _NotificationSettingsPage(
                    sound: widget.notificationSound,
                    vibration: widget.notificationVibration,
                    onSoundChanged: widget.onSoundChanged,
                    onVibrationChanged: widget.onVibrationChanged,
                  ),
                ),
              ),
            ),
            _settingsTile(
              icon: Icons.color_lens,
              title: "Theme",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _ThemeSettingsPage(
                    darkMode: widget.isDarkMode,
                    onThemeChanged: widget.onThemeChanged,
                  ),
                ),
              ),
            ),
            _settingsTile(
              icon: Icons.bar_chart,
              title: "Usage",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _UsagePage()),
              ),
            ),
            _settingsTile(
              icon: Icons.person,
              title: "Account",
              onTap: () async {
                final result = await Navigator.push<Map<String, String>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _AccountPage(
                      userId: widget.userId,
                      username: _username,
                      email: _email,
                    ),
                  ),
                );

                if (result != null) {
                  setState(() {
                    _username = result['username'] ?? _username;
                    _email = result['email'] ?? _email;
                  });
                }
              },
            ),
            _settingsTile(
              icon: Icons.login,
              title: "Login",
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoginPage(
                      isDarkMode: widget.isDarkMode,
                      onThemeChanged: widget.onThemeChanged,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required Function() onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 30),
        title: Text(title, style: const TextStyle(fontSize: 18)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
// SOCKETS PAGE
////////////////////////////////////////////////////////////////////////////////

class _SocketsPage extends StatefulWidget {
  @override
  State<_SocketsPage> createState() => _SocketsPageState();
}

class _SocketsPageState extends State<_SocketsPage> {
  List<Map<String, dynamic>> sockets = [];
  bool selectAll = false;

  @override
  void initState() {
    super.initState();
    loadSockets();
  }

  Future<void> loadSockets() async {
    final data = await LocalDatabase.getAllSockets();
    setState(() => sockets = data);
  }

  Future<void> addSocketDialog() async {
    String socketName = "";
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add New Socket"),
        content: TextField(
          decoration: const InputDecoration(labelText: "Enter Socket Name"),
          onChanged: (v) => socketName = v,
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Add"),
            onPressed: () async {
              if (socketName.trim().isEmpty) return;
              await LocalDatabase.insertSocket(socketName.trim());
              await loadSockets();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> removeSocket(int id) async {
    await LocalDatabase.deleteSocket(id);
    await loadSockets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sockets")),
      floatingActionButton: FloatingActionButton(
        onPressed: addSocketDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text("Select All"),
            value: selectAll,
            onChanged: (v) => setState(() => selectAll = v),
          ),
          Expanded(
            child: ListView(
              children: sockets.map((sock) {
                return Card(
                  child: ListTile(
                    title: Text(sock["name"]),
                    subtitle: Text("ID: ${sock["id"]}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => removeSocket(sock["id"]),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DashboardPage(
                            socketName: sock["name"],
                            selectedSockets: selectAll
                                ? sockets.map((e) => e["id"] as int).toList()
                                : [sock["id"]],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
// NOTIFICATION SETTINGS PAGE
////////////////////////////////////////////////////////////////////////////////

class _NotificationSettingsPage extends StatelessWidget {
  final bool sound;
  final bool vibration;
  final Function(bool) onSoundChanged;
  final Function(bool) onVibrationChanged;

  const _NotificationSettingsPage({
    Key? key,
    required this.sound,
    required this.vibration,
    required this.onSoundChanged,
    required this.onVibrationChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Sound"),
            value: sound,
            onChanged: onSoundChanged,
          ),
          SwitchListTile(
            title: const Text("Vibration"),
            value: vibration,
            onChanged: onVibrationChanged,
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
// THEME SETTINGS PAGE
////////////////////////////////////////////////////////////////////////////////

class _ThemeSettingsPage extends StatelessWidget {
  final bool darkMode;
  final Function(bool) onThemeChanged;

  const _ThemeSettingsPage({
    Key? key,
    required this.darkMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Theme Settings")),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: darkMode,
            onChanged: onThemeChanged,
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
// ACCOUNT PAGE
////////////////////////////////////////////////////////////////////////////////

class _AccountPage extends StatefulWidget {
  final int userId;
  final String username;
  final String email;

  const _AccountPage({
    Key? key,
    required this.userId,
    required this.username,
    required this.email,
  }) : super(key: key);

  @override
  State<_AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<_AccountPage> {
  bool _useFingerprint = false;
  late String _username;
  late String _email;

  @override
  void initState() {
    super.initState();
    _username = widget.username;
    _email = widget.email;
    _loadFingerprintPreference();
  }

  Future<void> _loadFingerprintPreference() async {
    bool pref = await LocalDatabase.getFingerprintPreference(widget.userId);
    setState(() => _useFingerprint = pref);
  }

  Future<void> _changeUsername() async {
    String newName = "";
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Change Username"),
        content: TextField(
          decoration: const InputDecoration(labelText: "New Username"),
          onChanged: (v) => newName = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              if (newName.trim().isEmpty) return;
              await LocalDatabase.updateUsername(widget.userId, newName.trim());
              setState(() => _username = newName.trim());
              Navigator.pop(context);
              Navigator.pop(context, {'username': _username, 'email': _email});
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _changeEmail() async {
    String newEmail = "";
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Change / Link Email"),
        content: TextField(
          decoration: const InputDecoration(labelText: "Email"),
          onChanged: (v) => newEmail = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              if (newEmail.trim().isEmpty) return;
              await LocalDatabase.updateEmail(widget.userId, newEmail.trim());
              setState(() => _email = newEmail.trim());
              Navigator.pop(context);
              Navigator.pop(context, {'username': _username, 'email': _email});
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    String pass = "";
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Change Password"),
        content: TextField(
          decoration: const InputDecoration(labelText: "New Password"),
          obscureText: true,
          onChanged: (v) => pass = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              if (pass.trim().isEmpty) return;
              await LocalDatabase.updatePassword(widget.userId, pass.trim());
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    bool confirm = false;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
            "This will permanently remove your username, email, password, and all local data.\n\nThis CANNOT be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              confirm = true;
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm) {
      await LocalDatabase.deleteUser(widget.userId);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LoginPage(
            isDarkMode: false,
            onThemeChanged: (_) {},
          ),
        ),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Account Settings")),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.badge),
            title: const Text("Change Username"),
            onTap: _changeUsername,
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text("Change / Link Email"),
            onTap: _changeEmail,
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text("Change Password"),
            onTap: _changePassword,
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text("Enable Fingerprint Login"),
            trailing: Switch(
              value: _useFingerprint,
              onChanged: (val) async {
                setState(() => _useFingerprint = val);
                await LocalDatabase.updateFingerprintPreference(widget.userId, val);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Delete Account", style: TextStyle(color: Colors.red)),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
// USAGE PAGE
////////////////////////////////////////////////////////////////////////////////

class _UsagePage extends StatefulWidget {
  @override
  State<_UsagePage> createState() => _UsagePageState();
}

class _UsagePageState extends State<_UsagePage> {
  String selectedSocket = "None Selected";
  String view = "Daily";

  Future<void> _selectSocketDialog() async {
    final sockets = await LocalDatabase.getAllSockets();

    String? chosen = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text("Select Socket"),
        children: sockets
            .map(
              (s) => SimpleDialogOption(
            child: Text(s["name"]),
            onPressed: () => Navigator.pop(context, s["name"]),
          ),
        )
            .toList(),
      ),
    );

    if (chosen != null) {
      setState(() => selectedSocket = chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Usage")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text("Current Socket: $selectedSocket",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: _selectSocketDialog,
              child: const Text("Select Socket"),
            ),
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ChoiceChip(
                label: const Text("Daily"),
                selected: view == "Daily",
                onSelected: (_) => setState(() => view = "Daily"),
              ),
              ChoiceChip(
                label: const Text("Weekly"),
                selected: view == "Weekly",
                onSelected: (_) => setState(() => view = "Weekly"),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            margin: const EdgeInsets.all(20),
            height: 250,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text("Bar Graph (Power / Current / Voltage)"),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Energy Used: 0.00 kWh", style: TextStyle(fontSize: 16)),
                Text("Max Power: -- W", style: TextStyle(fontSize: 16)),
                Text("Average Voltage: -- V", style: TextStyle(fontSize: 16)),
                Text("Peak Current: -- A", style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
