import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum QueryStatus {
  pending,
  assigned,
  inProgress,
  resolved,
  failed
}

class QueryLog {
  final String id;
  final String userId;
  final String userRole;
  final String query;
  final QueryStatus status;
  final DateTime timestamp;
  final String? response;
  final String? error;
  final String? assignedTo;
  final String? assignedBy;
  final DateTime? assignedAt;
  final DateTime? resolvedAt;

  QueryLog({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.query,
    required this.status,
    required this.timestamp,
    this.response,
    this.error,
    this.assignedTo,
    this.assignedBy,
    this.assignedAt,
    this.resolvedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userRole': userRole,
      'query': query,
      'status': status.toString().split('.').last,
      'timestamp': timestamp,
      'response': response,
      'error': error,
      'assignedTo': assignedTo,
      'assignedBy': assignedBy,
      'assignedAt': assignedAt,
      'resolvedAt': resolvedAt,
    };
  }

  factory QueryLog.fromMap(Map<String, dynamic> map) {
    return QueryLog(
      id: map['id'],
      userId: map['userId'],
      userRole: map['userRole'],
      query: map['query'],
      status: QueryStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      response: map['response'],
      error: map['error'],
      assignedTo: map['assignedTo'],
      assignedBy: map['assignedBy'],
      assignedAt: map['assignedAt'] != null ? (map['assignedAt'] as Timestamp).toDate() : null,
      resolvedAt: map['resolvedAt'] != null ? (map['resolvedAt'] as Timestamp).toDate() : null,
    );
  }
}

class QueryLoggingService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<QueryLog> _recentQueries = [];
  final bool _isLoading = false;

  List<QueryLog> get recentQueries => _recentQueries;
  bool get isLoading => _isLoading;

  Future<void> logQuery(String query) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final queryLog = QueryLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.uid,
        userRole: 'agent', // Default role, you might want to get this from user data
        query: query,
        status: QueryStatus.pending,
        timestamp: DateTime.now(),
      );

      await _firestore
          .collection('query_logs')
          .doc(queryLog.id)
          .set(queryLog.toMap());

      _recentQueries.insert(0, queryLog);
      if (_recentQueries.length > 50) {
        _recentQueries.removeLast();
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<QueryLog>> getRecentQueries() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('query_logs')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => QueryLog.fromMap(doc.data()))
          .toList();
    });
  }

  // Create a new query (for agents)
  Future<QueryLog> createQuery(String query) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userRole = userDoc.get('role') as String;
      if (userRole != 'agent') throw Exception('Only agents can create queries');

      final queryLog = QueryLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.uid,
        userRole: userRole,
        query: query,
        status: QueryStatus.pending,
        timestamp: DateTime.now(),
      );

      await _firestore
          .collection('queries')
          .doc(queryLog.id)
          .set(queryLog.toMap());

      return queryLog;
    } catch (e) {
      rethrow;
    }
  }

  // Assign query to agent (for supervisors)
  Future<void> assignQuery(String queryId, String agentId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userRole = userDoc.get('role') as String;
      if (userRole != 'supervisor') throw Exception('Only supervisors can assign queries');

      final agentDoc = await _firestore.collection('users').doc(agentId).get();
      if (!agentDoc.exists || agentDoc.get('role') != 'agent') {
        throw Exception('Invalid agent ID');
      }

      await _firestore.collection('queries').doc(queryId).update({
        'status': QueryStatus.assigned.toString().split('.').last,
        'assignedTo': agentId,
        'assignedBy': user.uid,
        'assignedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Update query status (for agents)
  Future<void> updateQueryStatus(
    String queryId,
    QueryStatus status, {
    String? response,
    String? error,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final queryDoc = await _firestore.collection('queries').doc(queryId).get();
      if (!queryDoc.exists) throw Exception('Query not found');

      final query = QueryLog.fromMap(queryDoc.data()!);
      if (query.assignedTo != user.uid) {
        throw Exception('You are not assigned to this query');
      }

      final Map<String, dynamic> updates = {
        'status': status.toString().split('.').last,
        if (response != null) 'response': response,
        if (error != null) 'error': error,
      };

      if (status == QueryStatus.resolved) {
        updates['resolvedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('queries').doc(queryId).update(updates);
    } catch (e) {
      rethrow;
    }
  }

  // Get assigned queries (for agents)
  Stream<List<QueryLog>> getAssignedQueries() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('queries')
        .where('assignedTo', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => QueryLog.fromMap(doc.data()))
          .toList();
    });
  }

  // Get all queries (for supervisors)
  Stream<List<QueryLog>> getAllQueries() {
    return _firestore
        .collection('queries')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => QueryLog.fromMap(doc.data()))
          .toList();
    });
  }

  // Get queries by status (for supervisors)
  Stream<List<QueryLog>> getQueriesByStatus(QueryStatus status) {
    return _firestore
        .collection('queries')
        .where('status', isEqualTo: status.toString().split('.').last)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => QueryLog.fromMap(doc.data()))
          .toList();
    });
  }

  // Get agents list (for supervisors)
  Stream<List<Map<String, dynamic>>> getAgents() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'agent')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    });
  }

  // Delete query (for supervisors)
  Future<void> deleteQuery(String queryId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userRole = userDoc.get('role') as String;
      if (userRole != 'supervisor') throw Exception('Only supervisors can delete queries');

      await _firestore.collection('queries').doc(queryId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Get queries by date range
  Future<List<QueryLog>> getQueriesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final snapshot = await _firestore
        .collection('queries')
        .where('timestamp', isGreaterThanOrEqualTo: startDate)
        .where('timestamp', isLessThanOrEqualTo: endDate)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => QueryLog.fromMap(doc.data()))
        .toList();
  }
} 