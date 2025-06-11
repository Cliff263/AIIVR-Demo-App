import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/query_logging_service.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';

class QueryLogScreen extends StatefulWidget {
  const QueryLogScreen({super.key});

  @override
  QueryLogScreenState createState() => QueryLogScreenState();
}

class QueryLogScreenState extends State<QueryLogScreen> {
  final QueryLoggingService _queryService = QueryLoggingService();
  QueryStatus? _selectedStatus;
  final _queryController = TextEditingController();
  bool _isSupervisor = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userRole = await authService.getUserRole();
    setState(() {
      _isSupervisor = userRole == UserRole.supervisor;
    });
  }

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

  Future<void> _assignQuery(String queryId) async {
    try {
      final agents = await _queryService.getAgents().first;
      if (!mounted) return;

      final selectedAgent = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Agent'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: agents.length,
              itemBuilder: (context, index) {
                final agent = agents[index];
                return ListTile(
                  title: Text(agent['email'] ?? 'Unknown'),
                  onTap: () => Navigator.pop(context, agent),
                );
              },
            ),
          ),
        ),
      );

      if (selectedAgent != null) {
        await _queryService.assignQuery(queryId, selectedAgent['id']);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Query assigned successfully')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _updateQueryStatus(String queryId, QueryStatus newStatus) async {
    try {
      await _queryService.updateQueryStatus(queryId, newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteQuery(String queryId) async {
    try {
      await _queryService.deleteQuery(queryId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Query deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8F5CFF), Color(0xFF5B7CFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (!_isSupervisor) // Agent view
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _queryController,
                          decoration: const InputDecoration(
                            hintText: 'Enter your query',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _createQuery,
                        icon: const Icon(Icons.add),
                        label: const Text('Log Query'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8F5CFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            if (_isSupervisor) // Supervisor view
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<QueryStatus>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Status',
                          border: OutlineInputBorder(),
                        ),
                        items: QueryStatus.values.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status.toString().split('.').last.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedStatus = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: StreamBuilder<List<QueryLog>>(
                    stream: _isSupervisor
                        ? (_selectedStatus != null
                            ? _queryService.getQueriesByStatus(_selectedStatus!)
                            : _queryService.getAllQueries())
                        : _queryService.getAssignedQueries(),
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
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(query.status),
                                child: Icon(_getStatusIcon(query.status), color: Colors.white),
                              ),
                              title: Text(query.query),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Status: ${query.status.toString().split('.').last.toUpperCase()}'),
                                  Text('Time: ${DateFormat('yyyy-MM-dd HH:mm').format(query.timestamp)}'),
                                  if (query.assignedTo != null)
                                    Text('Assigned To: ${query.assignedTo}'),
                                  if (query.response != null)
                                    Text('Response: ${query.response}'),
                                  if (query.error != null)
                                    Text('Error: ${query.error}', style: const TextStyle(color: Colors.red)),
                                ],
                              ),
                              trailing: _isSupervisor
                                  ? PopupMenuButton(
                                      itemBuilder: (context) => [
                                        if (query.status == QueryStatus.pending)
                                          const PopupMenuItem(
                                            value: 'assign',
                                            child: Text('Assign to Agent'),
                                          ),
                                        if (query.status != QueryStatus.resolved)
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete'),
                                          ),
                                      ],
                                      onSelected: (value) {
                                        if (value == 'assign') {
                                          _assignQuery(query.id);
                                        } else if (value == 'delete') {
                                          _deleteQuery(query.id);
                                        }
                                      },
                                    )
                                  : PopupMenuButton(
                                      itemBuilder: (context) => [
                                        if (query.status == QueryStatus.assigned)
                                          const PopupMenuItem(
                                            value: 'in_progress',
                                            child: Text('Mark as In Progress'),
                                          ),
                                        if (query.status == QueryStatus.inProgress)
                                          const PopupMenuItem(
                                            value: 'resolved',
                                            child: Text('Mark as Resolved'),
                                          ),
                                      ],
                                      onSelected: (value) {
                                        if (value == 'in_progress') {
                                          _updateQueryStatus(query.id, QueryStatus.inProgress);
                                        } else if (value == 'resolved') {
                                          _updateQueryStatus(query.id, QueryStatus.resolved);
                                        }
                                      },
                                    ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(QueryStatus status) {
    switch (status) {
      case QueryStatus.pending:
        return Colors.orange;
      case QueryStatus.assigned:
        return Colors.blue;
      case QueryStatus.inProgress:
        return Colors.purple;
      case QueryStatus.resolved:
        return Colors.green;
      case QueryStatus.failed:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(QueryStatus status) {
    switch (status) {
      case QueryStatus.pending:
        return Icons.pending;
      case QueryStatus.assigned:
        return Icons.assignment;
      case QueryStatus.inProgress:
        return Icons.work;
      case QueryStatus.resolved:
        return Icons.check_circle;
      case QueryStatus.failed:
        return Icons.error;
    }
  }
}