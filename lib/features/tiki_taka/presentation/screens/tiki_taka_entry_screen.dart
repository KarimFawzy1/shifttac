import 'package:flutter/material.dart';

import '../../data/local/tiki_taka_database.dart';
import '../state/tiki_taka_cubit.dart';
import 'tiki_taka_gameplay_screen.dart';

/// Opens [TikiTakaDatabase] on first access, then shows [TikiTakaGameplayScreen].
class TikiTakaEntryScreen extends StatefulWidget {
  const TikiTakaEntryScreen({
    super.key,
    this.cubit,
    this.autoLoadBoard = true,
  });

  /// When set (tests), skips database open and uses this cubit directly.
  final TikiTakaCubit? cubit;
  final bool autoLoadBoard;

  @override
  State<TikiTakaEntryScreen> createState() => _TikiTakaEntryScreenState();
}

class _TikiTakaEntryScreenState extends State<TikiTakaEntryScreen> {
  Future<void>? _openFuture;

  @override
  void initState() {
    super.initState();
    if (widget.cubit != null) {
      return;
    }
    _openFuture = _openDatabaseIfNeeded();
  }

  Future<void> _openDatabaseIfNeeded() async {
    final database = TikiTakaDatabase.instance;
    if (database.isOpen) {
      return;
    }
    await database.open();
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
          return Scaffold(
            body: Center(
              child: Text(
                'Could not load Tiki-Taka database.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return TikiTakaGameplayScreen(autoLoadBoard: widget.autoLoadBoard);
      },
    );
  }
}
