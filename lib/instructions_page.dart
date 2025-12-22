import 'package:flutter/material.dart';
import 'look_engine.dart';
import 'openai_service.dart';

class InstructionsPage extends StatefulWidget {
  final FaceProfile profile;
  final LookResult look;
  const InstructionsPage({super.key, required this.profile, required this.look});

  @override
  State<InstructionsPage> createState() => _InstructionsPageState();
}

class _InstructionsPageState extends State<InstructionsPage> {
  bool _loadingAI = false;
  String? _aiText;

  // Put your API key in openai_service.dart (or better: env/remote config)
  final _openAI = OpenAIService();

  Future<void> _generateAIInstructions() async {
    setState(() {
      _loadingAI = true;
      _aiText = null;
    });

    try {
      final text = await _openAI.generateMakeupInstructions(
        skinTone: widget.profile.skinTone.name,
        undertone: widget.profile.undertone.name,
        faceShape: widget.profile.faceShape.name,
        lookName: widget.look.lookName,
      );
      setState(() => _aiText = text);
    } catch (e) {
      setState(() => _aiText = 'AI error: $e');
    } finally {
      setState(() => _loadingAI = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final look = widget.look;

    return Scaffold(
      appBar: AppBar(title: const Text('Makeup Instructions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            look.lookName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Chip(label: Text('Tone: ${p.skinTone.name}')),
              Chip(label: Text('Undertone: ${p.undertone.name}')),
              Chip(label: Text('Face shape: ${p.faceShape.name}')),
            ],
          ),
          const SizedBox(height: 16),

          const Text(
            'Step-by-step (Rule-based)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),

          ...List.generate(look.steps.length, (i) {
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(look.steps[i]),
              ),
            );
          }),

          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loadingAI ? null : _generateAIInstructions,
                  icon: _loadingAI
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: const Text('Generate AI Tips (GPT)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_aiText != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_aiText!),
              ),
            ),

          const SizedBox(height: 24),
          Text(
            'Note: GPT receives only text labels (tone/undertone/face shape). No face image is sent.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
