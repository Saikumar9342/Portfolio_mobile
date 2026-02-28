import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/payment_screen.dart';
import 'firestore_service.dart';

class EntitlementState {
  final bool isAdmin;
  final bool isPremium;
  final String plan;
  final String status;

  const EntitlementState({
    required this.isAdmin,
    required this.isPremium,
    required this.plan,
    required this.status,
  });
}

class EntitlementService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  static const Set<String> _activePremiumStatuses = {
    'active',
    'trialing',
    'paid',
    'completed',
    'success',
  };

  bool _isPremiumFromBilling(Map<String, dynamic> data) {
    final plan = (data['plan'] ?? '').toString().toLowerCase();
    final status = (data['status'] ?? '').toString().toLowerCase();
    final isPremiumFlag = data['isPremium'] == true;
    final hasPremiumPlan = plan == 'premium' || plan.contains('premium');
    final hasActiveStatus = _activePremiumStatuses.contains(status);
    return isPremiumFlag || (hasPremiumPlan && hasActiveStatus);
  }

  Future<EntitlementState> getCurrentEntitlement() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const EntitlementState(
        isAdmin: false,
        isPremium: false,
        plan: 'free',
        status: 'none',
      );
    }

    final isAdmin = _firestoreService.isCurrentUserAdmin;
    if (isAdmin) {
      return const EntitlementState(
        isAdmin: true,
        isPremium: true,
        plan: 'admin',
        status: 'active',
      );
    }

    try {
      final billingSnap = await _db
          .collection('users')
          .doc(user.uid)
          .collection('billing')
          .doc('subscription')
          .get();

      if (billingSnap.exists) {
        final data = billingSnap.data() ?? {};
        final plan = (data['plan'] ?? 'free').toString().toLowerCase();
        final status = (data['status'] ?? 'inactive').toString().toLowerCase();
        final isPremium = _isPremiumFromBilling(data);
        return EntitlementState(
          isAdmin: false,
          isPremium: isPremium,
          plan: plan,
          status: status,
        );
      }
    } catch (_) {
      // Fallback to free if billing doc isn't available.
    }

    return const EntitlementState(
      isAdmin: false,
      isPremium: false,
      plan: 'free',
      status: 'inactive',
    );
  }

  Future<bool> ensurePremiumAccess(
    BuildContext context, {
    required String featureName,
  }) async {
    final entitlement = await getCurrentEntitlement();
    if (entitlement.isPremium || entitlement.isAdmin) {
      return true;
    }

    if (!context.mounted) return false;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(featureName: featureName),
      ),
    );
    return false;
  }
}
