import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen_l10n/app_localizations.dart';
import '../../models/note_tag.dart';
import '../../models/quote_model.dart';
import '../../services/database_service.dart';
import '../../widgets/quote_content_widget.dart';

class GrowthComparisonPage extends StatefulWidget {
  const GrowthComparisonPage({
    super.key,
    required this.tag,
    required this.onAdd,
  });

  final NoteTag tag;
  final Future<void> Function() onAdd;

  @override
  State<GrowthComparisonPage> createState() => _GrowthComparisonPageState();
}

class _GrowthComparisonPageState extends State<GrowthComparisonPage> {
  late final DatabaseService _database;
  late Future<({List<Quote> earliest, List<Quote> latest})> _records;
  int _earlierOffset = 0;
  int _laterOffset = 0;

  @override
  void initState() {
    super.initState();
    _database = context.read<DatabaseService>();
    _records = _load();
    _database.addListener(_refresh);
  }

  @override
  void dispose() {
    _database.removeListener(_refresh);
    super.dispose();
  }

  Future<({List<Quote> earliest, List<Quote> latest})> _load() async {
    final tags = [widget.tag.id];
    final results = await Future.wait([
      _database.getUserQuotes(
        tagIds: tags,
        orderBy: 'date ASC, id ASC',
        offset: _earlierOffset,
        limit: 2,
      ),
      _database.getUserQuotes(
        tagIds: tags,
        orderBy: 'date DESC, id DESC',
        offset: _laterOffset,
        limit: 2,
      ),
    ]);
    return (earliest: results.first, latest: results.last);
  }

  void _refresh() {
    setState(() => _records = _load());
  }

  Widget _recordCard(
    BuildContext context,
    List<Quote> records,
    int offset,
    ValueChanged<int> onOffsetChanged,
  ) {
    final quote = records.first;
    final date = MaterialLocalizations.of(context)
        .formatFullDate(quote.parsedDate.toLocal());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).previousPageTooltip,
                  onPressed: offset > 0
                      ? () => onOffsetChanged(offset - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(child: Text(date, textAlign: TextAlign.center)),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                  onPressed: records.length > 1
                      ? () => onOffsetChanged(offset + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            QuoteContent(
              key: ValueKey(quote.id),
              quote: quote,
              showFullContent: true,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.growthComparison),
        actions: [
          IconButton(
            tooltip: l10n.growthContinueRecording,
            onPressed: () async {
              await widget.onAdd();
              if (mounted) _refresh();
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _records,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(onPressed: _refresh, child: Text(l10n.retry)),
            );
          }
          final records = snapshot.requireData;
          if (records.earliest.isEmpty && records.latest.isEmpty &&
              _earlierOffset == 0 && _laterOffset == 0) {
            return Center(child: Text(l10n.noNotesFound));
          }
          if (records.earliest.isEmpty || records.latest.isEmpty) {
            return Center(
              child: TextButton(
                onPressed: () {
                  _earlierOffset = 0;
                  _laterOffset = 0;
                  _refresh();
                },
                child: Text(l10n.retry),
              ),
            );
          }

          final earlier = _recordCard(
            context,
            records.earliest,
            _earlierOffset,
            (offset) {
              _earlierOffset = offset;
              _refresh();
            },
          );
          final sameRecord =
              records.earliest.first.id == records.latest.first.id;
          if (sameRecord && _earlierOffset == 0 && _laterOffset == 0) {
            return ListView(padding: const EdgeInsets.all(12), children: [earlier]);
          }
          final later = _recordCard(
            context,
            records.latest,
            _laterOffset,
            (offset) {
              _laterOffset = offset;
              _refresh();
            },
          );
          return LayoutBuilder(
            builder: (context, constraints) => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (constraints.maxWidth >= 760)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Expanded(child: earlier), Expanded(child: later)],
                  )
                else ...[earlier, later],
              ],
            ),
          );
        },
      ),
    );
  }
}
