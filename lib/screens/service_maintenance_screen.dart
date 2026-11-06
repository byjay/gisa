import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/service_control_service.dart';

class ServiceMaintenanceGate extends StatelessWidget {
  const ServiceMaintenanceGate({
    super.key,
    required this.service,
    required this.child,
  });

  final ServiceControlService service;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) =>
        service.isEnabled ? child : ServiceMaintenanceScreen(service: service),
  );
}

class ServiceMaintenanceScreen extends StatefulWidget {
  const ServiceMaintenanceScreen({super.key, required this.service});

  final ServiceControlService service;

  @override
  State<ServiceMaintenanceScreen> createState() =>
      _ServiceMaintenanceScreenState();
}

class _ServiceMaintenanceScreenState extends State<ServiceMaintenanceScreen> {
  final _tokenController = TextEditingController();
  final _messageController = TextEditingController();
  bool _working = false;
  String? _adminMessage;

  @override
  void dispose() {
    _tokenController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    setState(() => _working = true);
    await widget.service.refresh();
    if (mounted) setState(() => _working = false);
  }

  Future<void> _registerToken() async {
    setState(() => _working = true);
    final result = await AdminService.instance.registerToken(
      _tokenController.text,
    );
    if (!mounted) return;
    setState(() {
      _working = false;
      _adminMessage = result == AdminAuthResult.success
          ? '운영자 토큰을 확인했습니다.'
          : '토큰 확인에 실패했습니다. 다시 확인해 주세요.';
      if (result == AdminAuthResult.success) _tokenController.clear();
    });
  }

  Future<void> _loadAdminStatus() async {
    setState(() => _working = true);
    try {
      final status = await widget.service.fetchAdminStatus();
      if (!mounted) return;
      _messageController.text = status.message;
      setState(
        () => _adminMessage = status.enabled
            ? '서비스가 사용 중입니다.'
            : '서비스가 중지되어 있습니다.',
      );
    } catch (error) {
      if (mounted) setState(() => _adminMessage = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    setState(() => _working = true);
    try {
      await widget.service.setEnabled(
        enabled: enabled,
        message: enabled ? '' : _messageController.text.trim(),
      );
      if (mounted) {
        setState(
          () => _adminMessage = enabled ? '서비스를 다시 시작했습니다.' : '서비스를 중지했습니다.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _adminMessage = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final hasToken = service.isAdminOverrideAvailable;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.build_circle_outlined, size: 64),
                  const SizedBox(height: 18),
                  const Text(
                    '서비스 점검 중',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    service.message.isEmpty
                        ? '서비스 상태를 확인할 수 없습니다.'
                        : service.message,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _working ? null : _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 확인'),
                  ),
                  const Divider(height: 40),
                  if (!hasToken) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '운영자 복구',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _tokenController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '서버 발급 운영자 토큰',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _working ? null : _registerToken,
                      child: const Text('토큰 확인'),
                    ),
                  ] else ...[
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: '점검 안내 문구',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _working ? null : _loadAdminStatus,
                          child: const Text('관리자 상태 불러오기'),
                        ),
                        FilledButton(
                          onPressed: _working ? null : () => _setEnabled(true),
                          child: const Text('서비스 다시 시작'),
                        ),
                        OutlinedButton(
                          onPressed: _working ? null : () => _setEnabled(false),
                          child: const Text('서비스 중지'),
                        ),
                      ],
                    ),
                  ],
                  if (_working) ...[
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(),
                  ],
                  if (_adminMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_adminMessage!, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
