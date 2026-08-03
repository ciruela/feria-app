import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../models/team_member.dart';
import '../../services/supabase_service.dart';
import '../../services/team_service.dart';
import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/section_header.dart';

/// Invitar cuentas (email) a la armería activa en Supabase.
class AdminTeamScreen extends StatefulWidget {
  const AdminTeamScreen({super.key});

  @override
  State<AdminTeamScreen> createState() => _AdminTeamScreenState();
}

class _AdminTeamScreenState extends State<AdminTeamScreen> {
  final _service = TeamService();
  List<TeamMember> _members = const [];
  bool _loading = false;
  String? _error;
  bool _needsMigration = false;

  bool get _canManage {
    final session = context.read<TenantSessionService>();
    return session.appRole == 'owner' || session.isPlatformAdmin;
  }

  String get _currentUserId =>
      SupabaseService.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AppConfig.useSupabase) return;
    setState(() {
      _loading = true;
      _error = null;
      _needsMigration = false;
    });
    try {
      final result = await _service.fetchMembers();
      if (!mounted) return;
      setState(() {
        _members = result.members;
        _needsMigration = result.migrationPending;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _invite() async {
    if (!_canManage) return;

    final result = await showDialog<_InviteForm>(
      context: context,
      builder: (_) => const _InviteDialog(),
    );
    if (result == null) return;

    setState(() => _loading = true);
    try {
      final invited = await _service.invite(
        email: result.email,
        nombre: result.nombre,
        rol: result.rol,
      );
      if (!mounted) return;
      final message = invited.emailSent
          ? 'Invitación enviada a ${invited.email}. '
              'Va a recibir un mail para crear su contraseña y entrar.'
          : '${invited.email} ya tenía cuenta: quedó agregada al equipo.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatInviteError(error))),
      );
    }
  }

  String _formatInviteError(Object error) {
    if (error is PostgrestException) {
      return error.message;
    }
    if (error is StateError) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _deactivate(TeamMember member) async {
    if (!_canManage || member.userId == _currentUserId) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quitar acceso'),
        content: Text(
          '¿Sacar a ${member.displayName} de la armería? '
          'No podrá entrar con su cuenta hasta que lo vuelvas a invitar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar acceso'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await _service.deactivate(member.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.displayName} ya no tiene acceso')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Equipo de la armería'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _loading ? null : _invite,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('INVITAR'),
            )
          : null,
      body: !AppConfig.useSupabase
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'El equipo en la nube requiere Supabase.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      _canManage
                          ? 'Invitá por email a quienes administran la armería. '
                              'Si todavía no tienen cuenta, les llega un mail '
                              'para crearla. Los vendedores del mostrador '
                              'entran con “Entrar como vendedor”.'
                          : 'Solo el dueño puede invitar administradores. '
                              'Los vendedores usan dominio + clave desde el inicio.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (_needsMigration) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Configuración pendiente en Supabase',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.danger,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Para invitar por email y ver todos los correos, ejecutá '
                            'supabase/migrations/011_team_members.sql en Supabase → SQL Editor. '
                            'Mientras tanto podés ver miembros básicos abajo.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: '${_members.length} persona${_members.length == 1 ? '' : 's'}',
                    subtitle: 'Cuentas con acceso a esta armería',
                  ),
                  const SizedBox(height: 12),
                  if (_loading && _members.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_members.isEmpty)
                    const _EmptyTeam()
                  else
                    ..._members.map(
                      (member) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MemberTile(
                          member: member,
                          isSelf: member.userId == _currentUserId,
                          canManage: _canManage,
                          onDeactivate:
                              member.isOwner ? null : () => _deactivate(member),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const SectionHeader(
                    title: 'PIN de administración',
                    subtitle: 'Distinto del login con email',
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Para saber quién hizo cada acción en el mostrador, cada persona '
                    'debe entrar a Administración con su PIN (pantalla Administradores). '
                    'El login con email es para acceder a la armería; el PIN identifica '
                    'quién está operando en ese momento.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isSelf,
    required this.canManage,
    this.onDeactivate,
  });

  final TeamMember member;
  final bool isSelf;
  final bool canManage;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: member.isOwner
              ? AppColors.gold.withValues(alpha: 0.2)
              : AppColors.primary.withValues(alpha: 0.12),
          child: Icon(
            member.isOwner ? Icons.star_rounded : Icons.person_rounded,
            color: member.isOwner ? AppColors.goldDark : AppColors.primary,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                member.displayName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (isSelf) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'VOS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${member.email.isEmpty ? 'sin email' : member.email} · '
          '${member.isOwner ? 'Dueño' : 'Admin'}'
          '${member.activo ? '' : ' · inactivo'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: canManage && onDeactivate != null
            ? IconButton(
                tooltip: 'Quitar acceso',
                onPressed: onDeactivate,
                icon: const Icon(Icons.person_remove_outlined,
                    color: AppColors.danger),
              )
            : null,
      ),
    );
  }
}

class _EmptyTeam extends StatelessWidget {
  const _EmptyTeam();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.groups_outlined, size: 40, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('Todavía no hay equipo cargado', style: TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _InviteForm {
  const _InviteForm({
    required this.email,
    required this.nombre,
    required this.rol,
  });

  final String email;
  final String nombre;
  final String rol;
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog();

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _nombre = TextEditingController();
  String _rol = 'admin';

  @override
  void dispose() {
    _email.dispose();
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invitar al equipo'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'persona@mail.com',
                helperText:
                    'Debe ser el mismo email con el que se registró en la app',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (!v.contains('@')) return 'Email inválido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Rol',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _rol,
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Administrador (panel)')),
                DropdownMenuItem(value: 'owner', child: Text('Dueño')),
              ],
                  onChanged: (value) {
                    if (value != null) setState(() => _rol = value);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(
                context,
                _InviteForm(
                  email: _email.text.trim(),
                  nombre: _nombre.text.trim(),
                  rol: _rol,
                ),
              );
            }
          },
          child: const Text('Invitar'),
        ),
      ],
    );
  }
}
