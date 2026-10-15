import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/filter_sidebar.dart';
import '../../../core/widgets/pagination_bar.dart';
import '../../dashboard/state/admin_data_store.dart';
import '../data/report_service.dart';
import '../models/leave_report.dart';
import 'date_range_dialog.dart';

/// Sección "Reportes": cuánto tiempo salieron, a dónde y por qué, con las
/// advertencias de no retorno. Se filtra por fechas, predio, motivo y persona.
class ReportsView extends StatefulWidget {
  final VoidCallback onUnauthorized;
  final ReportService? service;

  const ReportsView({super.key, required this.onUnauthorized, this.service});

  @override
  State<ReportsView> createState() => ReportsViewState();
}

enum _PersonSort { minutes, exits, average }

class ReportsViewState extends State<ReportsView> {
  static const _allPremises = 0;
  static const _allReasons = '';

  late final ReportService _service = widget.service ?? ReportService();
  final AdminDataStore _store = AdminDataStore.instance;
  final _searchController = TextEditingController();
  Timer? _debounce;

  late DateTimeRange _range = _defaultRange();
  int _premiseId = _allPremises;
  String _reason = _allReasons;
  _PersonSort _sort = _PersonSort.minutes;
  static const _pageSize = 10;
  int _peoplePage = 0;
  int _warnPage = 0;

  LeaveReport? _report;
  bool _isLoading = true;
  bool _loadFailed = false;
  int _requestId = 0;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTimeRange _defaultRange() {
    final today = _dateOnly(DateTime.now());
    return DateTimeRange(
      start: DateTime(today.year, today.month, today.day - 29),
      end: today,
    );
  }

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _store.removeListener(_onStore);
    _searchController.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  /// Vuelve a pedir el reporte. Público para refrescarlo desde fuera.
  Future<void> refresh() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    final id = ++_requestId;
    if (!silent || _report == null) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }
    try {
      final report = await _service.getLeaveReport(
        from: _range.start,
        to: _range.end,
        premiseId: _premiseId == _allPremises ? null : _premiseId,
        reason: _reason,
        search: _searchController.text,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _report = report;
        _peoplePage = 0;
        _warnPage = 0;
        _isLoading = false;
        _loadFailed = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      if (mounted && id == _requestId) {
        setState(() {
          _isLoading = false;
          _loadFailed = _report == null;
        });
      }
    } catch (_) {
      if (mounted && id == _requestId) {
        setState(() {
          _isLoading = false;
          _loadFailed = _report == null;
        });
      }
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _pickRange() async {
    final today = _dateOnly(DateTime.now());
    final picked = await showDateRangeDialog(
      context,
      initial: _range,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
    unawaited(_load());
  }

  int get _activeFilters =>
      (_premiseId != _allPremises ? 1 : 0) +
      (_reason != _allReasons ? 1 : 0) +
      (_searchController.text.trim().isNotEmpty ? 1 : 0) +
      (_range == _defaultRange() ? 0 : 1);

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _premiseId = _allPremises;
      _reason = _allReasons;
      _range = _defaultRange();
    });
    unawaited(_load());
  }

  // ---------------------------------------------------------------- format

  static String _day(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final days = minutes ~/ 1440;
    final hours = (minutes % 1440) ~/ 60;
    final mins = minutes % 60;
    if (days > 0) return hours == 0 ? '$days d' : '$days d $hours h';
    return mins == 0 ? '$hours h' : '$hours h $mins min';
  }

  String get _rangeLabel {
    final r = _range;
    return r.start == r.end
        ? _day(r.start)
        : '${_day(r.start)} – ${_day(r.end)}';
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return FilterSidebarLayout(
      wideBreakpoint: 1000,
      search: _buildSearchField(),
      activeCount: _activeFilters,
      onClear: _clearFilters,
      filters: [
        _buildPeriodFilter(),
        _buildPremiseFilter(),
        _buildReasonFilter(),
      ],
      content: _buildContent(),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      style: AppText.body,
      decoration: InputDecoration(
        hintText: 'Buscar por nombre o item...',
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.darkText,
          size: AppDimens.iconSize,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
          borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
        ),
      ),
    );
  }

  Widget _filterTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.darkText,
      ),
    ),
  );

  Widget _buildPeriodFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filterTitle('Fechas'),
        OutlinedButton.icon(
          onPressed: _pickRange,
          icon: const Icon(Icons.calendar_month_rounded, size: 20),
          label: Text(_rangeLabel),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppColors.darkText,
            side: const BorderSide(color: AppColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _dropdownDecoration() => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: AppColors.line),
    ),
  );

  Widget _buildPremiseFilter() {
    final premises = _store.premises;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filterTitle('Predio (a dónde)'),
        DropdownButtonFormField<int>(
          initialValue: _premiseId,
          isExpanded: true,
          decoration: _dropdownDecoration(),
          items: [
            const DropdownMenuItem(value: _allPremises, child: Text('Todos')),
            for (final p in premises)
              DropdownMenuItem(
                value: p.id,
                child: Text(p.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            setState(() => _premiseId = v ?? _allPremises);
            unawaited(_load());
          },
        ),
      ],
    );
  }

  Widget _buildReasonFilter() {
    final names = {for (final r in _store.reasons) r.name}.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filterTitle('Motivo (por qué)'),
        DropdownButtonFormField<String>(
          initialValue: _reason,
          isExpanded: true,
          decoration: _dropdownDecoration(),
          items: [
            const DropdownMenuItem(value: _allReasons, child: Text('Todos')),
            for (final name in names)
              DropdownMenuItem(
                value: name,
                child: Text(name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            setState(() => _reason = v ?? _allReasons);
            unawaited(_load());
          },
        ),
      ],
    );
  }

  Widget _buildContent() {
    final report = _report;
    if (_isLoading && report == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryRed),
      );
    }
    if (_loadFailed || report == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AppColors.danger,
            ),
            const SizedBox(height: 10),
            const Text(
              'No se pudo cargar el reporte',
              style: AppText.cardTitle,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth >= Breakpoints.tablet ? 24.0 : 16.0;
        final wide = constraints.maxWidth >= 860;

        final premises = _GroupCard(
          title: 'A dónde salen',
          subtitle: 'Predios, por tiempo fuera',
          icon: Icons.apartment_rounded,
          groups: report.byPremise,
          format: _duration,
        );
        final reasons = _GroupCard(
          title: 'Por qué salen',
          subtitle: 'Motivos, por tiempo fuera',
          icon: Icons.help_outline_rounded,
          groups: report.byReason,
          format: _duration,
        );

        return RefreshIndicator(
          onRefresh: () => _load(silent: true),
          color: Colors.white,
          backgroundColor: AppColors.primaryRed,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Opacity(
                      opacity: _isLoading ? 0.55 : 1,
                      child: _buildSummary(report.summary),
                    ),
                    const SizedBox(height: 24),
                    _buildWarnings(report),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: premises),
                          const SizedBox(width: 24),
                          Expanded(child: reasons),
                        ],
                      )
                    else ...[
                      premises,
                      const SizedBox(height: 24),
                      reasons,
                    ],
                    const SizedBox(height: 28),
                    _buildPeople(report.byUser),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------- summary

  Widget _buildSummary(ReportSummary s) {
    Widget item(IconData icon, String value, String label, {Color? color}) =>
        SizedBox(
          width: 150,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(icon, size: 26, color: color ?? Colors.grey.shade700),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: color ?? AppColors.darkText,
                          ),
                        ),
                      ),
                      Text(label, style: AppText.caption, maxLines: 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: AppColors.line)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          item(Icons.logout_rounded, '${s.exits}', 'Salidas'),
          item(Icons.timer_outlined, _duration(s.minutes), 'Tiempo fuera'),
          item(
            Icons.av_timer_rounded,
            _duration(s.averageMinutes),
            'Promedio por salida',
          ),
          item(Icons.groups_rounded, '${s.people}', 'Personas'),
          item(Icons.directions_walk_rounded, '${s.outsideNow}', 'Fuera ahora'),
          item(
            Icons.warning_amber_rounded,
            '${s.unreturned}',
            'Sin retorno',
            color: s.unreturned > 0 ? AppColors.danger : null,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- warnings

  Widget _buildWarnings(LeaveReport report) {
    if (report.unreturned.isEmpty && report.outsideNow.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (report.unreturned.isNotEmpty) ...[
            _SectionTitle(
              'Advertencias de no retorno',
              'Salidas de días anteriores que nunca marcaron retorno. '
                  'No suman al tiempo fuera.',
            ),
            const SizedBox(height: 12),
            for (final w in pageSlice(report.unreturned, _warnPage, _pageSize))
              _WarningTile(
                warning: w,
                danger: true,
                detail: 'Salió el ${_day(w.leftAt)} a las ${_time(w.leftAt)}',
              ),
            PaginationBar(
              page: _warnPage,
              pageSize: _pageSize,
              total: report.unreturned.length,
              onChanged: (p) => setState(() => _warnPage = p),
            ),
          ],
          if (report.outsideNow.isNotEmpty) ...[
            if (report.unreturned.isNotEmpty) const SizedBox(height: 20),
            _SectionTitle(
              'Fuera ahora',
              'Personas que salieron hoy y aún no regresan.',
            ),
            const SizedBox(height: 12),
            for (final w in report.outsideNow)
              _WarningTile(
                warning: w,
                danger: false,
                detail:
                    'Salió a las ${_time(w.leftAt)} · lleva ${_duration(w.minutes)}',
              ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- people

  List<ReportPerson> _sorted(List<ReportPerson> people) {
    final list = List.of(people);
    int key(ReportPerson p) => switch (_sort) {
      _PersonSort.minutes => p.minutes,
      _PersonSort.exits => p.exits,
      _PersonSort.average => p.averageMinutes,
    };
    list.sort((a, b) => key(b).compareTo(key(a)));
    return list;
  }

  Widget _buildPeople(List<ReportPerson> people) {
    final sorted = _sorted(people);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          'Por persona',
          '${people.length} ${people.length == 1 ? 'persona' : 'personas'} en el periodo.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label) in const [
              (_PersonSort.minutes, 'Más tiempo fuera'),
              (_PersonSort.exits, 'Más salidas'),
              (_PersonSort.average, 'Mayor promedio'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _sort == value,
                showCheckmark: false,
                selectedColor: AppColors.primaryRed,
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _sort == value ? Colors.white : AppColors.darkText,
                ),
                onSelected: (_) => setState(() {
                  _sort = value;
                  _peoplePage = 0;
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          const _EmptyNote('No hay salidas en este periodo con esos filtros.')
        else ...[
          for (final p in pageSlice(sorted, _peoplePage, _pageSize))
            _PersonTile(person: p, format: _duration),
          PaginationBar(
            page: _peoplePage,
            pageSize: _pageSize,
            total: sorted.length,
            onChanged: (p) => setState(() => _peoplePage = p),
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ widgets

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.sectionTitle),
        const SizedBox(height: 2),
        Text(subtitle, style: AppText.caption),
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;

  const _EmptyNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: Text(text, style: AppText.caption, textAlign: TextAlign.center),
    );
  }
}

class _WarningTile extends StatelessWidget {
  final ReportWarning warning;
  final bool danger;
  final String detail;

  const _WarningTile({
    required this.warning,
    required this.danger,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.info;
    final bg = danger ? AppColors.dangerBg : AppColors.infoBg;
    final where = [
      if (warning.premise != null) warning.premise!,
      if (warning.reason != null) warning.reason!,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Row(
        children: [
          Icon(
            danger
                ? Icons.warning_amber_rounded
                : Icons.directions_walk_rounded,
            color: color,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warning.item == null
                      ? warning.name
                      : '${warning.name} · ${warning.item}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (where.isNotEmpty)
                  Text(where, style: AppText.body.copyWith(fontSize: 15)),
                Text(detail, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista con una barra proporcional al tiempo fuera de cada predio o motivo.
class _GroupCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<ReportGroup> groups;
  final String Function(int minutes) format;

  const _GroupCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.groups,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final maxMinutes = groups.fold<int>(
      1,
      (max, g) => g.minutes > max ? g.minutes : max,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title, subtitle),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          const _EmptyNote('Sin salidas en este periodo.')
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            ),
            child: Column(
              children: [
                for (final g in groups)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(icon, size: 18, color: AppColors.info),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                g.name,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              format(g.minutes),
                              style: AppText.body.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: g.minutes / maxMinutes,
                            minHeight: 8,
                            backgroundColor: AppColors.infoBg,
                            color: AppColors.primaryRed,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${g.exits} ${g.exits == 1 ? 'salida' : 'salidas'}'
                          ' · ${g.people} ${g.people == 1 ? 'persona' : 'personas'}'
                          ' · promedio ${format(g.averageMinutes)}',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PersonTile extends StatelessWidget {
  final ReportPerson person;
  final String Function(int minutes) format;

  const _PersonTile({required this.person, required this.format});

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label) => Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          Text(label, style: AppText.caption.copyWith(fontSize: 12)),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          final stats = [
            stat('${person.exits}', 'salidas'),
            stat(format(person.minutes), 'tiempo fuera'),
            stat(format(person.averageMinutes), 'promedio'),
          ];
          final info = _info();
          if (!narrow) {
            return Row(
              children: [
                Expanded(child: info),
                ...stats,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              info,
              const SizedBox(height: 10),
              Row(children: [for (final s in stats) Expanded(child: s)]),
            ],
          );
        },
      ),
    );
  }

  Widget _info() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          person.name,
          overflow: TextOverflow.ellipsis,
          style: AppText.cardTitle,
        ),
        Text(
          [
            if (person.item != null) 'Item ${person.item}',
            'Más larga: ${format(person.longestMinutes)}',
          ].join(' · '),
          style: AppText.caption,
        ),
        if (person.unreturned > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 4),
                Text(
                  '${person.unreturned} sin retorno',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
