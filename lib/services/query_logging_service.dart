import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum QueryStatus {
  pending,
  processing,
  completed,
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

  QueryLog({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.query,
    required this.status,
    required this.timestamp,
    this.response,
    this.error,
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

  // Create a new query log
  Future<QueryLog> createQuery(String query) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get user role from Firestore
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userRole = userDoc.get('role') as String;

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
  }

  // Update query status
  Future<void> updateQueryStatus(
    String queryId,
    QueryStatus status, {
    String? response,
    String? error,
  }) async {
    final updates = {
      'status': status.toString().split('.').last,
      if (response != null) 'response': response,
      if (error != null) 'error': error,
    };

    await _firestore.collection('queries').doc(queryId).update(updates);
  }

  // Get queries for current user
  Stream<List<QueryLog>> getUserQueries() {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    return _firestore
        .collection('queries')
        .where('userId', isEqualTo: user.uid)
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

  // Get queries by status
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