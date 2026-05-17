import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const WeightTrackerApp());

class WeightTrackerApp extends StatelessWidget {
  const WeightTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const WeightTrackerHome(),
    );
  }
}

class WeightEntry {
  final DateTime date;
  final double weight;
  const WeightEntry(this.date, this.weight);

  Map<String, dynamic> toJson() => {
        'd': date.millisecondsSinceEpoch,
        'w': weight,
      };

  factory WeightEntry.fromJson(Map<String, dynamic> j) =>
      WeightEntry(DateTime.fromMillisecondsSinceEpoch(j['d']), (j['w'] as num).toDouble());
}

class WeightTrackerHome extends StatefulWidget {
  const WeightTrackerHome({super.key});
  @override
  State<WeightTrackerHome> createState() => _WeightTrackerHomeState();
}

class _WeightTrackerHomeState extends State<WeightTrackerHome> {
  final _weightCtl = TextEditingController();
  final _heightCtl = TextEditingController(text: '170');
  final _targetCtl = TextEditingController(text: '70');
  final _dateCtl = TextEditingController();

  List<WeightEntry> _entries = [];
  double _target = 70;

  @override
  void initState() {
    super.initState();
    _dateCtl.text = _formatDate(DateTime.now());
    _load();
  }

  @override
  void dispose() {
    _weightCtl.dispose();
    _heightCtl.dispose();
    _targetCtl.dispose();
    _dateCtl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('entries') ?? [];
    final entries = raw
        .map((e) => WeightEntry.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final t = prefs.getDouble('target') ?? 70;
    final h = prefs.getDouble('height') ?? 170;
    setState(() {
      _entries = entries;
      _target = t;
      _targetCtl.text = t.toStringAsFixed(1);
      _heightCtl.text = h.toStringAsFixed(1);
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'entries',
      _entries.map((e) => jsonEncode(e.toJson())).toList(),
    );
    await prefs.setDouble('target', _target);
    final h = double.tryParse(_heightCtl.text.trim());
    if (h != null) await prefs.setDouble('height', h);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      _dateCtl.text = _formatDate(picked);
    }
  }

  void _deleteEntry(int index) {
    setState(() => _entries.removeAt(index));
    _save();
  }

  void _addEntry() {
    final w = double.tryParse(_weightCtl.text.trim());
    if (w == null || w <= 0) {
      _showMsg('Enter a valid weight');
      return;
    }
    final date = DateTime.tryParse(_dateCtl.text.trim());
    if (date == null) {
      _showMsg('Enter a valid date (YYYY-MM-DD)');
      return;
    }
    final existing = _entries.indexWhere((e) => e.date == date);
    if (existing != -1) {
      _entries[existing] = WeightEntry(date, w);
    } else {
      _entries.add(WeightEntry(date, w));
    }
    _entries.sort((a, b) => a.date.compareTo(b.date));
    _weightCtl.clear();
    _dateCtl.text = _formatDate(DateTime.now());
    _save();
    setState(() {});
  }

  void _updateTarget() {
    final t = double.tryParse(_targetCtl.text.trim());
    if (t == null || t <= 0) {
      _showMsg('Enter a valid target weight');
      return;
    }
    _target = t;
    _save();
    setState(() {});
  }

  void _updateHeight() {
    final h = double.tryParse(_heightCtl.text.trim());
    if (h != null && h > 0) _save();
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  double get _bmi {
    if (_entries.isEmpty) return 0;
    final h = double.tryParse(_heightCtl.text.trim()) ?? 170;
    return _entries.last.weight / ((h / 100) * (h / 100));
  }

  String get _bmiLabel {
    final bmi = _bmi;
    if (bmi <= 0) return '--';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  double get _latestWeight => _entries.isNotEmpty ? _entries.last.weight : 0;

  double get _startWeight => _entries.isNotEmpty ? _entries.first.weight : 0;

  double get _minWeight =>
      _entries.isEmpty ? 0 : _entries.map((e) => e.weight).reduce(math.min);

  double get _maxWeight =>
      _entries.isEmpty ? 0 : _entries.map((e) => e.weight).reduce(math.max);

  double get _avgWeight =>
      _entries.isEmpty ? 0 : _entries.map((e) => e.weight).reduce((a, b) => a + b) / _entries.length;

  double get _progress {
    if (_entries.isEmpty || _target == 0) return 0;
    final totalChange = (_target - _startWeight).abs();
    if (totalChange < 0.01) return 1;
    final currentChange = (_latestWeight - _startWeight).abs();
    return (currentChange / totalChange).clamp(0.0, 1.0);
  }

  String get _trendLabel {
    if (_entries.length < 2) return '--';
    final first = _entries.first.weight;
    final last = _entries.last.weight;
    final diff = last - first;
    if (diff.abs() < 0.1) return '→ Stable';
    return diff > 0 ? '↑ +${diff.toStringAsFixed(1)} kg' : '↓ ${diff.toStringAsFixed(1)} kg';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Weight Tracker'), centerTitle: true),
      body: SafeArea(
        child: _entries.isEmpty ? _buildEmpty(theme) : _buildContent(theme),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInputSection(theme),
        const SizedBox(height: 40),
        Icon(Icons.monitor_weight_outlined, size: 100,
            color: theme.colorScheme.primary.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text('No weight entries yet.\nAdd your first entry above.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInputSection(theme),
        const SizedBox(height: 16),
        _buildStatsGrid(theme),
        const SizedBox(height: 16),
        _buildGoalProgress(theme),
        const SizedBox(height: 16),
        _buildWeightChart(theme),
        const SizedBox(height: 16),
        _buildEntryList(theme),
      ],
    );
  }

  Widget _buildInputSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateCtl,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _weightCtl,
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      prefixIcon: Icon(Icons.monitor_weight),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _addEntry,
              icon: const Icon(Icons.add),
              label: const Text('Add Entry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(ThemeData theme) {
    final bmiColor = _bmi >= 18.5 && _bmi < 25 ? Colors.green : Colors.orange;
    return Row(
      children: [
        Expanded(child: _statCard('BMI', _bmi <= 0 ? '--' : _bmi.toStringAsFixed(1),
            _bmiLabel, bmiColor)),
        const SizedBox(width: 8),
        Expanded(child: _statCard('Weight', '${_latestWeight.toStringAsFixed(1)} kg',
            _trendLabel, theme.colorScheme.primary)),
        const SizedBox(width: 8),
        Expanded(child: _statCard('Goal', '${_target.toStringAsFixed(1)} kg',
            '${(_progress * 100).toStringAsFixed(0)}%', Colors.teal)),
      ],
    );
  }

  Widget _statCard(String label, String value, String sub, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(sub, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalProgress(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Target Progress', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${_startWeight.toStringAsFixed(1)} kg',
                    style: theme.textTheme.bodySmall),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 14,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                Text('${_target.toStringAsFixed(1)} kg',
                    style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetCtl,
                    decoration: const InputDecoration(
                      labelText: 'Target (kg)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 40,
                  width: 80,
                  child: FilledButton(onPressed: _updateTarget, child: const Text('Set')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightChart(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weight Trend', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: CustomPaint(
                size: const Size(double.infinity, 200),
                painter: _WeightChartPainter(
                  entries: _entries,
                  target: _target,
                  lineColor: theme.colorScheme.primary,
                  dotColor: theme.colorScheme.primary,
                  targetColor: Colors.teal,
                  gridColor: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryList(ThemeData theme) {
    final stats = 'min: ${_minWeight.toStringAsFixed(1)}  '
        'max: ${_maxWeight.toStringAsFixed(1)}  '
        'avg: ${_avgWeight.toStringAsFixed(1)}  '
        'trend: $_trendLabel';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Entries', style: theme.textTheme.titleSmall),
                const SizedBox(width: 8),
                Text('(${_entries.length})', style: theme.textTheme.bodySmall),
                const Spacer(),
                Text('Height: ',
                    style: theme.textTheme.bodySmall),
                SizedBox(
                  width: 70,
                  height: 36,
                  child: TextField(
                    controller: _heightCtl,
                    decoration: const InputDecoration(
                      suffixText: 'cm',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateHeight(),
                    onSubmitted: (_) {
                      _updateHeight();
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(stats, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            ...List.generate(
              _entries.length,
              (i) {
                final e = _entries[_entries.length - 1 - i];
                return ListTile(
                  dense: true,
                  leading: Text(_formatDate(e.date)),
                  title: Text('${e.weight.toStringAsFixed(1)} kg'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _deleteEntry(_entries.length - 1 - i),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  final List<WeightEntry> entries;
  final double target;
  final Color lineColor;
  final Color dotColor;
  final Color targetColor;
  final Color gridColor;

  _WeightChartPainter({
    required this.entries,
    required this.target,
    required this.lineColor,
    required this.dotColor,
    required this.targetColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    const padding = 20.0;
    final chartW = size.width - padding * 2;
    final chartH = size.height - padding * 2;

    final allWeights = [...entries.map((e) => e.weight), target];
    double minW = allWeights.reduce(math.min);
    double maxW = allWeights.reduce(math.max);
    final range = (maxW - minW) * 1.1;
    if (range < 1) {
      minW = minW - 0.5;
      maxW = maxW + 0.5;
    }
    final actualRange = maxW - minW;

    // Grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final y = padding + chartH * i / 4;
      canvas.drawLine(Offset(padding, y), Offset(padding + chartW, y), gridPaint);
      final label = (maxW - actualRange * i / 4).toStringAsFixed(1);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: gridColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(0, y - 6));
    }

    // Points
    final points = <Offset>[];
    for (var i = 0; i < entries.length; i++) {
      final x = padding + (entries.length > 1 ? chartW * i / (entries.length - 1) : chartW / 2);
      final y = padding + chartH * (1 - (entries[i].weight - minW) / actualRange);
      points.add(Offset(x, y));
    }

    // Line
    if (points.length >= 2) {
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, linePaint);
    }

    // Dots
    final dotPaint = Paint()..color = dotColor;
    for (final p in points) {
      canvas.drawCircle(p, 4, dotPaint);
    }

    // Target line
    final targetY = padding + chartH * (1 - (target - minW) / actualRange);
    final targetLinePaint = Paint()
      ..color = targetColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(padding, targetY),
      Offset(padding + chartW, targetY),
      targetLinePaint,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'Target',
        style: TextStyle(color: targetColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(padding + chartW - 45, targetY - 16));
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) =>
      entries != oldDelegate.entries || target != oldDelegate.target;
}
