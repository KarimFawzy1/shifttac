import 'package:flutter/material.dart';

import '../../data/local/tiki_taka_database.dart';
import '../state/tiki_taka_cubit.dart';
import '../widgets/tiki_taka_database_error_view.dart';
import 'tiki_taka_gameplay_screen.dart';

/// Opens [TikiTakaDatabase] on first access, then shows [TikiTakaGameplayScreen].
class TikiTakaEntryScreen extends StatefulWidget {
  const TikiTakaEntryScreen({
    super.key,
    this.cubit,
    this.database,
    this.autoLoadBoard = true,
  });

  /// When set (tests), skips database open and uses this cubit directly.
  final TikiTakaCubit? cubit;

  /// When set (tests), overrides [TikiTakaDatabase.instance].
  final TikiTakaDatabase? database;
  final bool autoLoadBoard;

  @override
  State<TikiTakaEntryScreen> createState() => _TikiTakaEntryScreenState();
}

class _TikiTakaEntryScreenState extends State<TikiTakaEntryScreen> {
  Future<void>? _openFuture;
  TikiTakaCubit? _gameplayCubit;

  TikiTakaDatabase get _database => widget.database ?? TikiTakaDatabase.instance;

  @override
  void initState() {
    super.initState();
    if (widget.cubit != null) {
      return;
    }
    _openFuture = _openDatabaseIfNeeded();
  }

  @override
  void dispose() {
    if (widget.cubit == null) {
      _gameplayCubit?.close();
    }
    super.dispose();
  }

  Future<void> _openDatabaseIfNeeded() async {
    if (_database.isOpen) {
      return;
    }
    await _database.open();
  }

  void _retryOpen() {
    _gameplayCubit?.close();
    _gameplayCubit = null;
    setState(() {
      _openFuture = _openDatabaseIfNeeded();
    });
  }

  TikiTakaCubit _cubitForGameplay() {
    return _gameplayCubit ??= TikiTakaCubit(
      dependencies: TikiTakaDependencies.fromDatabase(_database.database),
      autoLoadBoard: widget.autoLoadBoard,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cubit != null) {
      return TikiTakaGameplayScreen(
        cubit: widget.cubit,
        autoLoadBoard: widget.autoLoadBoard,
      );
    }

    return FutureBuilder<void>(
      future: _openFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return TikiTakaDatabaseErrorView(
            error: snapshot.error!,
            onRetry: _retryOpen,
          );
        }
        return TikiTakaGameplayScreen(
          cubit: _cubitForGameplay(),
          autoLoadBoard: widget.autoLoadBoard,
        );
      },
    );
  }
}
