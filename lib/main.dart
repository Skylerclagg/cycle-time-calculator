import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cycle Time Calculator',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(primary: Colors.tealAccent),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.tealAccent,
            foregroundColor: Colors.black,
          ),
        ),
      ),
      home: MatchCycleCalculator(),
    );
  }
}

class MatchCycleCalculator extends StatefulWidget {
  @override
  _MatchCycleCalculatorState createState() => _MatchCycleCalculatorState();
}

class _MatchCycleCalculatorState extends State<MatchCycleCalculator> {
  final _numTeamsController = TextEditingController();
  final _matchesPerTeamController = TextEditingController();

  int _numberOfDays = 1;
  int _numberOfBlocks = 1;
  String _selectedEvent = 'ADC';

  List<TimeOfDay?> _dayStarts = [];
  List<TimeOfDay?> _dayEnds = [];
  List<TextEditingController> _dayLunches = [];

  bool _advancedMode = false;
  List<TimeOfDay?> _blockStarts = [];
  List<TimeOfDay?> _blockEnds = [];

  bool _separateOutput = false;
  bool _matchesPerDay = false;

  String _results = '';

  @override
  void initState() {
    super.initState();
    _initializeLists();
  }

  void _initializeLists() {
    _resizeList(_dayStarts, _numberOfDays, null);
    _resizeList(_dayEnds, _numberOfDays, null);
    _resizeList(_dayLunches, _numberOfDays, TextEditingController());
    _resizeList(_blockStarts, _numberOfBlocks, null);
    _resizeList(_blockEnds, _numberOfBlocks, null);
  }

  void _resizeList<T>(List<T> list, int newSize, T defaultValue) {
    if (list.length < newSize) {
      list.addAll(List.generate(newSize - list.length, (_) => defaultValue));
    } else if (list.length > newSize) {
      list.removeRange(newSize, list.length);
    }
  }

  int getMatchTimeForProgram(String program) {
    switch (program) {
      case 'ADC':
        return 90;
      case 'V5RC':
        return 120;
      case 'VIQRC':
        return 60;
      case 'VURC':
        return 120;
      default:
        return 90;
    }
  }

  int getTeamsOnFieldForProgram(String program) {
    switch (program) {
      case 'ADC':
        return 2;
      case 'V5RC':
        return 4;
      case 'VIQRC':
        return 2;
      case 'VURC':
        return 2;
      default:
        return 2;
    }
  }

  void calculateSchedule() {
    int numTeams = int.tryParse(_numTeamsController.text) ?? 0;
    int matchesPerTeam = int.tryParse(_matchesPerTeamController.text) ?? 0;
    int matchTimeSec = getMatchTimeForProgram(_selectedEvent);
    int teamsPerMatch = getTeamsOnFieldForProgram(_selectedEvent);

    int totalTeamAppearances = numTeams * matchesPerTeam;
    int totalMatches = _matchesPerDay
        ? ((totalTeamAppearances * _numberOfDays) / teamsPerMatch).ceil()
        : (totalTeamAppearances / teamsPerMatch).ceil();

    if (_advancedMode) {
      int totalMinutes = 0;
      List<int> blockMinutes = [];

      for (int i = 0; i < _numberOfBlocks; i++) {
        if (_blockStarts[i] == null || _blockEnds[i] == null) {
          setState(() {
            _results = 'Please select start and end time for all blocks.';
          });
          return;
        }
        int startMin = _blockStarts[i]!.hour * 60 + _blockStarts[i]!.minute;
        int endMin = _blockEnds[i]!.hour * 60 + _blockEnds[i]!.minute;
        int blockMin = endMin - startMin;
        blockMinutes.add(blockMin);
        totalMinutes += blockMin;
      }

      String result = 'Advanced Mode Results:\n';
      for (int i = 0; i < _numberOfBlocks; i++) {
        int blockMatches =
            (totalMatches * (blockMinutes[i] / totalMinutes)).round();
        result += _computeDaySchedule(
            'Time Block ${i + 1}', blockMinutes[i], blockMatches, matchTimeSec);
      }

      result += _computeDaySchedule(
          'Combined', totalMinutes, totalMatches, matchTimeSec);

      setState(() {
        _results = result;
      });
      return;
    }

    int totalMinutes = 0;
    List<int> dayMinutes = [];
    for (int i = 0; i < _numberOfDays; i++) {
      if (_dayStarts[i] == null || _dayEnds[i] == null) {
        setState(() {
          _results = 'Please enter start and end times for all days.';
        });
        return;
      }
      int startMin = _dayStarts[i]!.hour * 60 + _dayStarts[i]!.minute;
      int endMin = _dayEnds[i]!.hour * 60 + _dayEnds[i]!.minute;
      int lunchMin = int.tryParse(_dayLunches[i].text) ?? 0;
      int minutes = endMin - startMin - lunchMin;
      dayMinutes.add(minutes);
      totalMinutes += minutes;
    }

    List<int> dayMatches = List.generate(_numberOfDays, (_) => 0);
    if (_matchesPerDay) {
      for (int i = 0; i < _numberOfDays; i++) {
        dayMatches[i] = (numTeams * matchesPerTeam / teamsPerMatch).ceil();
      }
    } else {
      for (int i = 0; i < _numberOfDays; i++) {
        dayMatches[i] =
            (totalMatches * (dayMinutes[i] / totalMinutes)).round();
      }
    }

    String result = '';
    if (_separateOutput) {
      for (int i = 0; i < _numberOfDays; i++) {
        result += _computeDaySchedule(
            'Day ${i + 1}', dayMinutes[i], dayMatches[i], matchTimeSec);
      }
    } else {
      result += _computeDaySchedule(
          'Combined', totalMinutes, totalMatches, matchTimeSec);
      result += 'Matches per Day:\n';
      for (int i = 0; i < _numberOfDays; i++) {
        double matchesPerTeamDay =
            numTeams > 0 ? (dayMatches[i] * teamsPerMatch) / numTeams : 0;
        result +=
            'Day ${i + 1} → ${dayMatches[i]} matches (${matchesPerTeamDay.toStringAsFixed(2)} matches/team)\n';
      }
    }

    setState(() {
      _results = result;
    });
  }

  String _computeDaySchedule(
      String label, int availableMinutes, int matches, int matchTimeSec) {
    if (matches == 0 || availableMinutes == 0) {
      return '$label: No matches scheduled.\n\n';
    }

    int totalSeconds = availableMinutes * 60;
    double cycleTimeSec = totalSeconds / matches;
    double timeBetweenSec = cycleTimeSec - matchTimeSec;
    String hoursText = (availableMinutes / 60).toStringAsFixed(2);

    String formatTime(double seconds) {
      int min = seconds ~/ 60;
      int sec = (seconds % 60).round();
      return '${min}m ${sec}s';
    }
//- Available time: ${availableMinutes} m (${hoursText} h)
    return '''
$label:
- Matches: $matches
- Cycle time: ${formatTime(cycleTimeSec)}
- Time between: ${formatTime(timeBetweenSec)}
''';
  }

  Future<void> _pickTime(BuildContext context, String label,
      ValueChanged<TimeOfDay> onPicked, TimeOfDay? existingTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: existingTime ?? TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  Widget buildSpinnerRow({
    required String label,
    required int value,
    required int min,
    required int max,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 16))),
          IconButton(
            icon: Icon(Icons.remove),
            onPressed: value > min ? onDecrement : null,
          ),
          SizedBox(
            width: 50,
            child: TextField(
              readOnly: true,
              textAlign: TextAlign.center,
              controller: TextEditingController(text: value.toString()),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: value < max ? onIncrement : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _resizeList(_dayStarts, _numberOfDays, null);
    _resizeList(_dayEnds, _numberOfDays, null);
    _resizeList(_dayLunches, _numberOfDays, TextEditingController());
    _resizeList(_blockStarts, _numberOfBlocks, null);
    _resizeList(_blockEnds, _numberOfBlocks, null);

    return Scaffold(
      appBar: AppBar(
        title: Text('Cycle Time Calculator'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['ADC', 'V5RC', 'VIQRC', 'VURC'].map((type) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedEvent = type;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedEvent == type
                              ? Colors.tealAccent
                              : Colors.grey,
                          foregroundColor: Colors.black,
                        ),
                        child: Text(type),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextField(
                      controller: _numTeamsController,
                      decoration: InputDecoration(
                        labelText: 'Number of Teams',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: TextField(
                      controller: _matchesPerTeamController,
                      decoration: InputDecoration(
                        labelText: 'Matches per Team',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              title: Text('Advanced Mode (Time Blocks)'),
              value: _advancedMode,
              onChanged: (value) {
                setState(() {
                  _advancedMode = value;
                });
              },
            ),
            if (_advancedMode) ...[
              buildSpinnerRow(
                label: 'Number of Time Blocks',
                value: _numberOfBlocks,
                min: 1,
                max: 10,
                onDecrement: () {
                  setState(() {
                    _numberOfBlocks--;
                  });
                },
                onIncrement: () {
                  setState(() {
                    _numberOfBlocks++;
                  });
                },
              ),
              ...List.generate(_numberOfBlocks, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _pickTime(
                              context,
                              'Time Block ${index + 1} Start',
                              (t) => setState(() =>
                                  _blockStarts[index] = t),
                              _blockStarts[index]),
                          child: Text(_blockStarts[index]?.format(context) ??
                              'Time Block ${index + 1} start time'),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _pickTime(
                              context,
                              'Time Block ${index + 1} End',
                              (t) => setState(() =>
                                  _blockEnds[index] = t),
                              _blockEnds[index]),
                          child: Text(_blockEnds[index]?.format(context) ??
                              'Time Block ${index + 1} end time'),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (!_advancedMode) ...[
              buildSpinnerRow(
                label: 'Number of Days',
                value: _numberOfDays,
                min: 1,
                max: 5,
                onDecrement: () {
                  setState(() {
                    _numberOfDays--;
                  });
                },
                onIncrement: () {
                  setState(() {
                    _numberOfDays++;
                  });
                },
              ),
              ...List.generate(_numberOfDays, (index) {
                return _buildDaySection(
                  context,
                  'Day ${index + 1}',
                  _dayStarts[index],
                  _dayEnds[index],
                  (t) => setState(() => _dayStarts[index] = t),
                  (t) => setState(() => _dayEnds[index] = t),
                  _dayLunches[index],
                );
              }),
            ],
            /*
            SwitchListTile(
              title: Text('Set Matches Per Day Instead'),
              value: _matchesPerDay,
              onChanged: (value) {
                setState(() {
                  _matchesPerDay = value;
                });
              },
            ),
            if (_numberOfDays > 1)
              SwitchListTile(
                title: Text('Separate Days Output'),
                value: _separateOutput,
                onChanged: (value) {
                  setState(() {
                    _separateOutput = value;
                  });
                },
              ),
              */
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: calculateSchedule,
              child: Text('Calculate'),
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _results.isEmpty ? 'Results will appear here' : _results,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildDaySection(
    BuildContext context,
    String day,
    TimeOfDay? start,
    TimeOfDay? end,
    ValueChanged<TimeOfDay> onStartPicked,
    ValueChanged<TimeOfDay> onEndPicked,
    TextEditingController lunchCtrl) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(day, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _pickTime(
                context,
                '$day Start',
                onStartPicked,
                start ?? TimeOfDay(hour: 9, minute: 0),
              ),
              child: Text(start?.format(context) ?? '$day start time'),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _pickTime(
                context,
                '$day End',
                onEndPicked,
                end ?? TimeOfDay(hour: 12, minute: 0),
              ),
              child: Text(end?.format(context) ?? '$day end time'),
            ),
          ),
        ],
      ),
      SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextField(
          controller: lunchCtrl,
          decoration: InputDecoration(
            labelText: 'Lunch Break (minutes)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
      ),
    ],
  );
}

}
