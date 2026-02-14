import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/inquiry.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_card.dart';
import 'package:url_launcher/url_launcher.dart';

class InquiriesScreen extends StatefulWidget {
  const InquiriesScreen({super.key});

  @override
  State<InquiriesScreen> createState() => _InquiriesScreenState();
}

class _InquiriesScreenState extends State<InquiriesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('LEADS & INQUIRIES'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final inquiries = snapshot.data!.docs
              .map((doc) => Inquiry.fromFirestore(doc))
              .toList();

          if (inquiries.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: inquiries.length,
            itemBuilder: (context, index) {
              final inq = inquiries[index];
              return Dismissible(
                key: Key(inq.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) =>
                    _showDeleteConfirmation(context, inq),
                onDismissed: (direction) => _deleteInquiry(inq),
                background: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.delete_sweep_rounded,
                      color: Colors.redAccent),
                ),
                child: _InquiryCard(
                  inquiry: inq,
                  onDelete: (item) async {
                    final confirmed =
                        await _showDeleteConfirmation(context, item);
                    if (confirmed == true) {
                      _deleteInquiry(item);
                    }
                  },
                  onReply: _replyViaEmail,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mark_email_read_outlined,
              size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.2)),
          const SizedBox(height: 24),
          Text(
            "No messages yet",
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your leads will appear here when\nsomeone contacts you via your portfolio.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(
      BuildContext context, Inquiry inquiry) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white10),
        ),
        title: Text(
          "DELETE INQUIRY",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        content: Text(
          "Are you sure you want to delete the message from ${inquiry.name}?\nThis action cannot be undone.",
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("CANCEL",
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("DELETE",
                style: GoogleFonts.inter(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _deleteInquiry(Inquiry inquiry) {
    FirebaseFirestore.instance.collection('messages').doc(inquiry.id).delete();
  }

  void _replyViaEmail(Inquiry inquiry) async {
    final String firstName = inquiry.name.split(' ').first;
    final String body = "Hi $firstName,\n\n"
        "[ Write your response here ]\n\n"
        "Best regards,\n"
        "Saikumar\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        "  � REFERENCE INFORMATION\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        "👤 FROM:      ${inquiry.name.toUpperCase()}\n"
        "📧 EMAIL:     ${inquiry.email}\n"
        "📅 RECEIVED:  ${DateFormat('MMM dd, yyyy - hh:mm a').format(inquiry.timestamp)}\n\n"
        "📝 ORIGINAL MESSAGE:\n"
        "\"${inquiry.message}\"\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        "Sent via Portfolio Admin Dashboard";

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: inquiry.email,
      query: _encodeQueryParameters(<String, String>{
        'subject': 'RE: Portfolio Inquiry - ${inquiry.name}',
        'body': body,
      }),
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      }
    } catch (e) {
      debugPrint("Could not launch email: $e");
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}

class _InquiryCard extends StatelessWidget {
  final Inquiry inquiry;
  final Function(Inquiry) onDelete;
  final Function(Inquiry) onReply;

  const _InquiryCard({
    required this.inquiry,
    required this.onDelete,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUnread = inquiry.status == 'unread';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.05),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          border: Border.all(
            color: isUnread
                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showDetail(context),
              child: Stack(
                children: [
                  if (isUnread)
                    Positioned(
                      left: 0,
                      top: 20,
                      bottom: 20,
                      width: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(4)),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    inquiry.name.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    inquiry.email,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isUnread)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "NEW",
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          inquiry.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('MMM dd, hh:mm a')
                                  .format(inquiry.timestamp),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color:
                                  AppTheme.textSecondary.withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    if (inquiry.status == 'unread') {
      FirebaseFirestore.instance
          .collection('messages')
          .doc(inquiry.id)
          .update({'status': 'read'});
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppTheme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    inquiry.name[0].toUpperCase(),
                    style: GoogleFonts.outfit(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inquiry.name,
                      style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary),
                    ),
                    Text(inquiry.email,
                        style:
                            GoogleFonts.inter(color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
            const Divider(height: 48, color: Colors.white10),
            if (inquiry.subject != null) ...[
              Text("SUBJECT",
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Text(inquiry.subject!,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 24),
            ],
            Text("MESSAGE",
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  inquiry.message,
                  style: GoogleFonts.inter(
                      fontSize: 16, color: AppTheme.textSecondary, height: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onReply(inquiry);
                    },
                    icon: const Icon(Icons.reply_rounded),
                    label: const Text("REPLY"),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDelete(inquiry);
                    },
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
