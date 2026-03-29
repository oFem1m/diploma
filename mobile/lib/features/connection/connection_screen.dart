import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/ws/ws_client.dart';
import 'connection_cubit.dart';
import '../configuration/config_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _hostController = TextEditingController(text: '10.0.2.2');
  final _portController = TextEditingController(text: '8765');

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _connect() {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8765;
    if (host.isEmpty) return;
    context.read<ConnectionCubit>().connect(host, port);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оптимизатор BBO')),
      body: BlocConsumer<ConnectionCubit, WsConnectionState>(
        listener: (context, state) {
          if (state is ConnectionConnected) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<ConnectionCubit>(),
                  child: RepositoryProvider.value(
                    value: context.read<WsClient>(),
                    child: ConfigScreen(capabilities: state.hello.capabilities),
                  ),
                ),
              ),
            );
          }
          if (state is ConnectionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          final isConnecting = state is ConnectionConnecting;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.dns_outlined, size: 64, color: Colors.indigo),
                const SizedBox(height: 24),
                TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Хост',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.computer),
                  ),
                  enabled: !isConnecting,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'Порт',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !isConnecting,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: isConnecting ? null : _connect,
                  icon: isConnecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.link),
                  label: Text(isConnecting ? 'Подключение...' : 'Подключиться'),
                ),
                const SizedBox(height: 24),
                if (state is ConnectionDisconnected &&
                    state.recentServers.isNotEmpty) ...[
                  Text(
                    'Недавние серверы',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ...state.recentServers.map((s) => ListTile(
                        leading: const Icon(Icons.history),
                        title: Text('${s['host']}:${s['port']}'),
                        onTap: () {
                          _hostController.text = s['host'] as String;
                          _portController.text = '${s['port']}';
                          _connect();
                        },
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      )),
                ],
                if (state is ConnectionError) ...[
                  const SizedBox(height: 16),
                  _StatusBadge(
                    icon: Icons.error_outline,
                    color: Colors.red,
                    label: 'Отключено',
                  ),
                ] else if (state is ConnectionDisconnected) ...[
                  const SizedBox(height: 16),
                  _StatusBadge(
                    icon: Icons.link_off,
                    color: Colors.grey,
                    label: 'Нет соединения',
                  ),
                ] else if (isConnecting) ...[
                  const SizedBox(height: 16),
                  _StatusBadge(
                    icon: Icons.sync,
                    color: Colors.orange,
                    label: 'Подключение...',
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _StatusBadge({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
