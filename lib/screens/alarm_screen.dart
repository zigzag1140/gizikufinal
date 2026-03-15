import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:giziku/services/notification_service.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  late Timer _timer;

  String _countdownString = "-- : -- : --";
  String _headerLabel = "Memuat alarm...";

  List<Map<String, dynamic>> alarms = [
    {
      'id': 1,
      'time': const TimeOfDay(hour: 8, minute: 0),
      'label': 'Sarapan',
      'isActive': false,
    },
    {
      'id': 2,
      'time': const TimeOfDay(hour: 13, minute: 30),
      'label': 'Makan Siang',
      'isActive': false,
    },
    {
      'id': 3,
      'time': const TimeOfDay(hour: 19, minute: 0),
      'label': 'Makan Malam',
      'isActive': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAlarms();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // --- FUNGSI LOAD & SAVE DATA ---
  Future<void> _loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final String? alarmsJson = prefs.getString('saved_alarms');

    if (alarmsJson != null) {
      List<dynamic> decodedList = jsonDecode(alarmsJson);
      setState(() {
        alarms = decodedList
            .map((item) {
              final timeParts = item['time'].split(':');
              return {
                'id': item['id'],
                'label': item['label'],
                'isActive': item['isActive'],
                'time': TimeOfDay(
                  hour: int.parse(timeParts[0]),
                  minute: int.parse(timeParts[1]),
                ),
              };
            })
            .toList()
            .cast<Map<String, dynamic>>();
      });
    } else {
      _saveAlarmsToPrefs();
    }
    _updateCountdown();
  }

  Future<void> _saveAlarmsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    String encodedData = jsonEncode(
      alarms.map((alarm) {
        final t = alarm['time'] as TimeOfDay;
        return {
          'id': alarm['id'],
          'label': alarm['label'],
          'isActive': alarm['isActive'],
          'time': '${t.hour}:${t.minute}',
        };
      }).toList(),
    );
    await prefs.setString('saved_alarms', encodedData);
  }

  // --- LOGIKA HITUNG MUNDUR ---
  void _updateCountdown() {
    DateTime now = DateTime.now();
    List<Map<String, dynamic>> activeSchedules = [];

    for (var alarm in alarms) {
      if (alarm['isActive'] == true) {
        TimeOfDay t = alarm['time'];
        DateTime scheduleDate = DateTime(
          now.year,
          now.month,
          now.day,
          t.hour,
          t.minute,
        );

        if (scheduleDate.isBefore(now)) {
          scheduleDate = scheduleDate.add(const Duration(days: 1));
        }
        activeSchedules.add({'date': scheduleDate, 'label': alarm['label']});
      }
    }

    if (mounted) {
      setState(() {
        if (activeSchedules.isEmpty) {
          _countdownString = "00 : 00 : 00";
          _headerLabel = "Aktifkan Alarm";
        } else {
          activeSchedules.sort(
            (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
          );
          DateTime nextSchedule = activeSchedules.first['date'];
          String nextLabel = activeSchedules.first['label'];

          Duration diff = nextSchedule.difference(now);
          String twoDigits(int n) => n.toString().padLeft(2, "0");
          _countdownString =
              "${twoDigits(diff.inHours)} : ${twoDigits(diff.inMinutes.remainder(60))} : ${twoDigits(diff.inSeconds.remainder(60))}";
          _headerLabel = "Menuju $nextLabel";
        }
      });
    }
  }

  // --- LOGIKA TOGGLE & EDIT ---
  void _toggleAlarm(int index, bool value) async {
    setState(() {
      alarms[index]['isActive'] = value;
    });
    _saveAlarmsToPrefs();

    if (value) {
      await NotificationService().scheduleDailyNotification(
        id: alarms[index]['id'],
        title: "Waktunya ${alarms[index]['label']}!",
        body: "Yuk catat makananmu di Giziku.",
        time: alarms[index]['time'],
      );
    } else {
      await NotificationService().cancelNotification(alarms[index]['id']);
    }
    _updateCountdown();
  }

  void _saveNewTime(int index, TimeOfDay newTime) async {
    setState(() {
      alarms[index]['time'] = newTime;
    });
    _saveAlarmsToPrefs();

    if (alarms[index]['isActive']) {
      await NotificationService().cancelNotification(alarms[index]['id']);
      await NotificationService().scheduleDailyNotification(
        id: alarms[index]['id'],
        title: "Waktunya ${alarms[index]['label']}!",
        body: "Jangan lupa makan ya!",
        time: newTime,
      );
    }
    _updateCountdown();
  }

  void _showEditAlarmSheet(int index) {
    TimeOfDay selectedTime = alarms[index]['time'];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2ECC45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return SizedBox(
          height: 400,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Atur Pengingat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.white),
                      onPressed: () {
                        _saveNewTime(index, selectedTime);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: DateTime(
                      2024,
                      1,
                      1,
                      selectedTime.hour,
                      selectedTime.minute,
                    ),
                    use24hFormat: true,
                    onDateTimeChanged: (DateTime newTime) {
                      selectedTime = TimeOfDay.fromDateTime(newTime);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // KITA HAPUS BOTTOM NAVIGATION BAR DARI SINI
    // KARENA SUDAH DI-HANDLE OLEH HOME_SCREEN (INDUK)
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage('assets/images/geprek.png'),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                _headerLabel,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                _countdownString,
                style: const TextStyle(
                  color: Color(0xFF2ECC45),
                  fontSize: 48,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Alarms',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 10),

              // LIST ALARM
              ...List.generate(alarms.length, (index) {
                var alarm = alarms[index];
                String formattedTime =
                    '${alarm['time'].hour.toString().padLeft(2, '0')}:${alarm['time'].minute.toString().padLeft(2, '0')}';

                return GestureDetector(
                  onTap: () => _showEditAlarmSheet(index),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: alarm['isActive']
                          ? const Color(0xFF2ECC45)
                          : const Color(0xFF2ECC45).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                formattedTime,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                alarm['label'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w400,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Transform.scale(
                          scale: 1.0,
                          child: Switch(
                            value: alarm['isActive'],
                            activeColor: Colors.white,
                            activeTrackColor: Colors.black,
                            inactiveThumbColor: Colors.grey,
                            inactiveTrackColor: Colors.white.withOpacity(0.5),
                            onChanged: (bool value) {
                              _toggleAlarm(index, value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
