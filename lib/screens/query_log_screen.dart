import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/query_logging_service.dart';
import '../services/auth_service.dart';

class QueryLogScreen extends StatefulWidget {
  const QueryLogScreen({super.key});

  @override
  QueryLogScreenState createState() => QueryLogScreenState();
}

class QueryLogScreenState extends State<QueryLogScreen> {
  final QueryLoggingService _queryService = QueryLoggingService();
  QueryStatus? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _createQuery() async {
    if (_queryController.text.isEmpty) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _queryService.createQuery(_queryController.text);
      _queryController.clear();
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Query logged successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isSupervisor = authService.currentUser?.email?.contains('supervisor') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Query Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => _buildFilterSheet(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: const InputDecoration(
                      hintText: 'Enter your query',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _createQuery,
                  child: const Text('Log Query'),
                ),
              ],
            ),
          ),
          if (_selectedStatus != null || _startDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_selectedStatus != null)
                    Chip(
                      label: Text('Status: ${_selectedStatus.toString().split('.').last}'),
                      onDeleted: () => setState(() => _selectedStatus = null),
                    ),
                  if (_startDate != null && _endDate != null)
                    Chip(
                      label: Text(
                        'Date: ${_startDate!.toString().split(' ')[0]} - ${_endDate!.toString().split(' ')[0]}',
                      ),
                      onDeleted: () => setState(() {
                        _startDate = null;
                        _endDate = null;
                      }),
                    ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<QueryLog>>(
              stream: _selectedStatus != null
                  ? _queryService.getQueriesByStatus(_selectedStatus!)
                  : isSupervisor
                      ? _queryService.getAllQueries()
                      : _queryService.getUserQueries(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final queries = snapshot.data!;
                if (queries.isEmpty) {
                  return const Center(child: Text('No queries found'));
                }

                return ListView.builder(
                  itemCount: queries.length,
                  itemBuilder: (context, index) {
                    final query = queries[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(query.query),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: ${query.status.toString().split('.').last}'),
                            Text('Role: ${query.userRole}'),
                            Text(
                              'Time: ${query.timestamp.toString().split('.')[0]}',
                            ),
                            if (query.response != null)
                              Text('Response: ${query.response}'),
                            if (query.error != null)
                              Text(
                                'Error: ${query.error}',
                                style: const TextStyle(color: Colors.red),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Filter Queries',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<QueryStatus>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: QueryStatus.values.map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(status.toString().split('.').last),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedStatus = value);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _selectDateRange();
              Navigator.pop(context);
            },
            child: const Text('Select Date Range'),
          ),
        ],
      ),
    );
  }
} 