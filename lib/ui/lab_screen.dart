import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../whoop_ble.dart';

/// Experiment screen: edit the 11 unknown bytes of the haptic command and send
/// them, to find which byte controls the spacing between pulses.
/// Safety: the loop byte (last) is fixed at 1 (two pulses) so every test is short.
class LabScreen extends StatefulWidget {
  const LabScreen({super.key, required this.ble});
  final WhoopController ble;
  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  // body bytes b0..b10 are editable; b11 (loop) is fixed at 1 below.
  final List<int> body = [0x01, 0x2F, 0x98, 0, 0, 0, 0, 0, 0, 0, 0];
  int sel = 3;
  bool sweeping = false;
  final List<String> log = [];

  WhoopController get ble => widget.ble;

  static String hx(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  static String hexOf(List<int> b) => b.map(hx).join(' ');

  void _add(String s) {
    if (!mounted) return;
    setState(() {
      log.insert(0, s);
      if (log.length > 60) log.removeLast();
    });
  }

  Future<void> _send(List<int> b, String note) async {
    final full = [...b, 0x01]; // fixed loop byte = 1 (two pulses)
    try {
      await ble.sendRawHex('13 ${hexOf(full)}', wrap: true);
      _add('SENT $note  ${hexOf(full)}');
    } catch (e) {
      _add('ERROR $e');
    }
  }

  void _bump(int d) => setState(() => body[sel] = (body[sel] + d) & 0xFF);

  Future<void> _sweep() async {
    if (!ble.isReady) {
      _add('Not connected');
      return;
    }
    setState(() => sweeping = true);
    const values = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0xFF];
    for (final v in values) {
      if (!sweeping || !mounted) break;
      if (v == body[sel]) continue;
      final b = List<int>.of(body);
      b[sel] = v;
      await _send(b, 'sweep b$sel=0x${hx(v)}');
      await Future.delayed(const Duration(seconds: 5));
    }
    if (mounted) setState(() => sweeping = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), children: [
      const Text('LAB', style: TextStyle(fontSize: 12, letterSpacing: 2, color: Color(0xFF8E8E93))),
      const SizedBox(height: 8),
      const Text(
        'Experimental. Each send is one haptic command with 2 pulses (loop byte fixed at 1). '
        'Change one byte, send, and feel whether the gap between the two pulses changes. '
        'If a value causes a buzz that will not stop, reboot the strap in the official WHOOP app '
        '(device icon > Device Settings > Advanced).',
        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12, height: 1.4),
      ),
      const SizedBox(height: 16),
      const Text('Pick a byte (b0..b10)', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (var i = 0; i < body.length; i++)
          ChoiceChip(
            label: Text('b$i ${hx(body[i])}'),
            selected: sel == i,
            onSelected: sweeping ? null : (_) => setState(() => sel = i),
          ),
      ]),
      const SizedBox(height: 12),
      Text('b$sel = 0x${hx(body[sel])} (${body[sel]})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        OutlinedButton(onPressed: sweeping ? null : () => _bump(-16), child: const Text('-16')),
        OutlinedButton(onPressed: sweeping ? null : () => _bump(-1), child: const Text('-1')),
        OutlinedButton(onPressed: sweeping ? null : () => _bump(1), child: const Text('+1')),
        OutlinedButton(onPressed: sweeping ? null : () => _bump(16), child: const Text('+16')),
        OutlinedButton(
            onPressed: sweeping ? null : () => setState(() => body[sel] = 0), child: const Text('0')),
      ]),
      const SizedBox(height: 12),
      Text('Body: ${hexOf([...body, 0x01])}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      const SizedBox(height: 12),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: sweeping
            ? null
            : () {
                if (!ble.isReady) {
                  _add('Not connected');
                  return;
                }
                _send(body, 'b$sel=0x${hx(body[sel])}');
              },
        child: const Text('SEND THIS'),
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: sweeping ? () => setState(() => sweeping = false) : _sweep,
        child: Text(sweeping ? 'STOP SWEEP' : 'SWEEP b$sel (9 values, 5 s apart)'),
      ),
      const SizedBox(height: 18),
      Row(children: [
        const Expanded(child: Text('Log (newest first)', style: TextStyle(fontWeight: FontWeight.w600))),
        TextButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: log.reversed.join('\n'))),
          child: const Text('Copy'),
        ),
      ]),
      for (final l in log)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(l, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFB0B0B5))),
        ),
    ]);
  }
}
