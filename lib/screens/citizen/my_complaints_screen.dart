import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'complaint_details_screen.dart';

class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
  String selectedFilter = "All";
  String searchText = "";
  bool sortMostUpvoted = false;

  final List<String> filters = ["All", "Pending", "In Progress", "Fixed"];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    final query = FirebaseFirestore.instance
        .collection("complaints")
        .where("userId", isEqualTo: user.uid)
        .orderBy("createdAt", descending: true);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0B1220)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // TOP BAR
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        "My Reports",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    // ⭐ Sort Button
                    IconButton(
                      tooltip: "Sort by Upvotes",
                      onPressed: () {
                        setState(() => sortMostUpvoted = !sortMostUpvoted);
                      },
                      icon: Icon(
                        sortMostUpvoted
                            ? Icons.trending_up_rounded
                            : Icons.sort_rounded,
                        color: sortMostUpvoted
                            ? const Color(0xFF38BDF8)
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // SEARCH BAR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.30),
                          blurRadius: 18,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "Search by type, status, address...",
                        hintStyle: TextStyle(color: Colors.white54),
                        prefixIcon: Icon(Icons.search, color: Colors.white54),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchText = value.trim().toLowerCase();
                        });
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // FILTER BUTTONS
              SizedBox(
                height: 46,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final f = filters[index];
                    final isSelected = selectedFilter == f;

                    return _FancyFilterChip(
                      label: f,
                      isSelected: isSelected,
                      onTap: () => setState(() => selectedFilter = f),
                      color: _filterColor(f),
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: query.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "Error: ${snapshot.error}",
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF38BDF8),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    // APPLY FILTER + SEARCH
                    List<QueryDocumentSnapshot> filteredDocs = docs.where((
                      doc,
                    ) {
                      final data = doc.data() as Map<String, dynamic>;

                      final status = (data["status"] ?? "Pending").toString();
                      final type = (data["type"] ?? "Unknown").toString();
                      final desc = (data["description"] ?? "").toString();
                      final address = (data["address"] ?? "").toString();

                      final statusMatch = selectedFilter == "All"
                          ? true
                          : status.toLowerCase().contains(
                              selectedFilter.toLowerCase(),
                            );

                      final searchMatch = searchText.isEmpty
                          ? true
                          : (type.toLowerCase().contains(searchText) ||
                                desc.toLowerCase().contains(searchText) ||
                                status.toLowerCase().contains(searchText) ||
                                address.toLowerCase().contains(searchText));

                      return statusMatch && searchMatch;
                    }).toList();

                    // ⭐ SORT BY MOST UPVOTED
                    if (sortMostUpvoted) {
                      filteredDocs.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final aVotes = (aData["upvotes"] ?? 0) as int;
                        final bVotes = (bData["upvotes"] ?? 0) as int;
                        return bVotes.compareTo(aVotes);
                      });
                    }

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                color: Colors.white70,
                                size: 42,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "No reports found",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                "Try another filter or search keyword.",
                                style: TextStyle(color: Colors.white60),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // ✅ GRID SQUARE BOXES (Reduced Height)
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio:
                                1.25, // 🔥 smaller height square feel
                          ),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;

                        final type = (data["type"] ?? "Unknown").toString();
                        final desc = (data["description"] ?? "").toString();
                        final status = (data["status"] ?? "Pending").toString();
                        final address = (data["address"] ?? "No address")
                            .toString();
                        final imgUrl = (data["imageUrl"] ?? "").toString();
                        final upvotes = (data["upvotes"] ?? 0);

                        DateTime? createdAt;
                        final ts = data["createdAt"];
                        if (ts is Timestamp) createdAt = ts.toDate();

                        final dateText = createdAt == null
                            ? "Just now"
                            : DateFormat("dd MMM").format(createdAt);

                        final statusColor = _statusColor(status);

                        return _SquareComplaintCard(
                          type: type,
                          desc: desc,
                          address: address,
                          dateText: dateText,
                          status: status,
                          statusColor: statusColor,
                          imgUrl: imgUrl,
                          upvotes: upvotes,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ComplaintDetailsScreen(
                                  complaintId: doc.id,
                                  complaintData: data,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _filterColor(String f) {
    final s = f.toLowerCase();
    if (s.contains("fixed")) return const Color(0xFF22C55E);
    if (s.contains("progress")) return const Color(0xFF60A5FA);
    if (s.contains("pending")) return const Color(0xFFF59E0B);
    return const Color(0xFF38BDF8);
  }

  static Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains("fixed")) return const Color(0xFF22C55E);
    if (s.contains("progress")) return const Color(0xFF60A5FA);
    return const Color(0xFFF59E0B);
  }
}

// ===================== Fancy Filter Chip =====================
class _FancyFilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _FancyFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  State<_FancyFilterChip> createState() => _FancyFilterChipState();
}

class _FancyFilterChipState extends State<_FancyFilterChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: widget.isSelected
                    ? widget.color.withOpacity(0.95)
                    : Colors.white.withOpacity(0.14),
                width: 1.2,
              ),
              gradient: LinearGradient(
                colors: widget.isSelected
                    ? [
                        widget.color.withOpacity(0.35),
                        widget.color.withOpacity(0.15),
                      ]
                    : [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.05),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_hover ? 0.55 : 0.30),
                  blurRadius: _hover ? 26 : 18,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 10,
                  width: 10,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isSelected ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== SQUARE GRID CARD =====================
class _SquareComplaintCard extends StatefulWidget {
  final String type;
  final String desc;
  final String address;
  final String dateText;
  final String status;
  final Color statusColor;
  final String imgUrl;
  final dynamic upvotes;
  final VoidCallback onTap;

  const _SquareComplaintCard({
    required this.type,
    required this.desc,
    required this.address,
    required this.dateText,
    required this.status,
    required this.statusColor,
    required this.imgUrl,
    required this.upvotes,
    required this.onTap,
  });

  @override
  State<_SquareComplaintCard> createState() => _SquareComplaintCardState();
}

class _SquareComplaintCardState extends State<_SquareComplaintCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                widget.statusColor.withOpacity(_hover ? 0.18 : 0.12),
                Colors.white.withOpacity(0.06),
                Colors.black.withOpacity(0.25),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: _hover
                  ? widget.statusColor.withOpacity(0.65)
                  : Colors.white.withOpacity(0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_hover ? 0.55 : 0.30),
                blurRadius: _hover ? 32 : 22,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // top image
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 90, // reduced height
                  width: double.infinity,
                  color: Colors.white.withOpacity(0.06),
                  child: widget.imgUrl.isEmpty
                      ? const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white54,
                        )
                      : Image.network(
                          widget.imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                widget.type,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                widget.desc.isEmpty ? "No description" : widget.desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12.2),
              ),

              const Spacer(),

              // Upvotes row
              Row(
                children: [
                  const Icon(
                    Icons.thumb_up_alt_rounded,
                    size: 14,
                    color: Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "${widget.upvotes ?? 0}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: widget.statusColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: widget.statusColor.withOpacity(0.35),
                      ),
                    ),
                    child: Text(
                      widget.status,
                      style: TextStyle(
                        color: widget.statusColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 13,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.dateText,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
