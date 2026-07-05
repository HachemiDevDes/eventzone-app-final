import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../theme/eventzone_theme.dart';

class LeaderboardAnalyticsScreen extends StatefulWidget {
  const LeaderboardAnalyticsScreen({super.key});

  @override
  State<LeaderboardAnalyticsScreen> createState() => _LeaderboardAnalyticsScreenState();
}

class _LeaderboardAnalyticsScreenState extends State<LeaderboardAnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _leaderboard = [];
  List<Map<String, dynamic>> _myConnections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch Leaderboard via RPC
      final leaderboardResponse = await _supabase.rpc('get_global_leaderboard');
      
      // Fetch Personal Analytics
      final userId = _supabase.auth.currentUser?.id;
      List<dynamic> connectionsResponse = [];
      if (userId != null) {
        connectionsResponse = await _supabase
            .from('connections')
            .select('created_at, title, company, source')
            .eq('user_id', userId);
      }

      setState(() {
        _leaderboard = List<Map<String, dynamic>>.from(leaderboardResponse as List);
        _myConnections = List<Map<String, dynamic>>.from(connectionsResponse);
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EventzoneTheme.backgroundStart,
      appBar: AppBar(
        toolbarHeight: 100,
        title: const Padding(
          padding: EdgeInsets.only(top: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Leaderboard", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: Colors.white)),
              SizedBox(height: 4),
              Text("See how you rank among other professionals", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.normal)),
            ],
          ),
        ),
        backgroundColor: EventzoneTheme.backgroundStart,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: EventzoneTheme.primaryAction.withOpacity(0.2),
                  border: Border.all(color: EventzoneTheme.primaryAction.withOpacity(0.5)),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: EventzoneTheme.primaryAction,
                unselectedLabelColor: Colors.white60,
                splashBorderRadius: BorderRadius.circular(30),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.trophy, size: 18),
                        SizedBox(width: 8),
                        Text('Leaderboard', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.barChart2, size: 18),
                        SizedBox(width: 8),
                        Text('Analytics', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: EventzoneTheme.primaryAction))
        : TabBarView(
            controller: _tabController,
            children: [
              _buildLeaderboardTab(),
              _buildAnalyticsTab(),
            ],
          ),
    );
  }

  // --- LEADERBOARD TAB ---

  Widget _buildLeaderboardTab() {
    if (_leaderboard.isEmpty) {
      return const Center(child: Text('No leaderboard data available yet.'));
    }

    final top3 = _leaderboard.take(3).toList();
    final rest = _leaderboard.skip(3).toList();

    int myRank = -1;
    Map<String, dynamic>? myData;
    final myId = _supabase.auth.currentUser?.id;
    for (int i = 0; i < _leaderboard.length; i++) {
      if (_leaderboard[i]['id'] == myId) {
        myRank = i + 1;
        myData = _leaderboard[i];
        break;
      }
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _fetchData,
          color: EventzoneTheme.primaryAction,
          child: ListView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 100),
            children: [
              _buildPodium(top3),
              const SizedBox(height: 32),
              ...rest.asMap().entries.map((entry) {
                final index = entry.key + 4; // Start at rank 4
                final user = entry.value;
                return _buildRankCard(user, index);
              }),
            ],
          ),
        ),
        if (myData != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: EventzoneTheme.primaryAction.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildRankCard(myData, myRank, isFloating: true),
            ),
          ),
      ],
    );
  }

  ImageProvider? _getAvatarProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) {
      return NetworkImage(url);
    } else {
      try {
        String base64Str = url;
        if (url.contains(',')) {
          base64Str = url.split(',').last;
        }
        return MemoryImage(base64Decode(base64Str));
      } catch (e) {
        return null;
      }
    }
  }

  Widget _buildPodium(List<Map<String, dynamic>> top3) {
    if (top3.isEmpty) return const SizedBox();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (top3.length > 1) _buildPodiumPlace(top3[1], 2, const Color(0xFFC0C0C0)), // Silver
        if (top3.isNotEmpty) Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: _buildPodiumPlace(top3[0], 1, const Color(0xFFFFD700)), // Gold
        ),
        if (top3.length > 2) _buildPodiumPlace(top3[2], 3, const Color(0xFFCD7F32)), // Bronze
      ],
    );
  }

  Widget _buildPodiumPlace(Map<String, dynamic> user, int rank, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: rank == 1 ? 4 : 3),
              ),
              child: CircleAvatar(
                radius: rank == 1 ? 40 : 32,
                backgroundColor: Colors.white12,
                backgroundImage: _getAvatarProvider(user['avatar_url']),
                child: _getAvatarProvider(user['avatar_url']) == null 
                    ? Text(user['full_name']?[0] ?? '?', style: TextStyle(color: Colors.white, fontSize: rank == 1 ? 24 : 18))
                    : null,
              ),
            ),
            Positioned(
              bottom: -10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: rank == 1 ? 100 : 85,
          child: Text(
            user['full_name'] ?? 'Unknown',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white, 
              fontWeight: rank == 1 ? FontWeight.bold : FontWeight.w600, 
              fontSize: rank == 1 ? 16 : 14
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${user['connection_count']}',
              style: TextStyle(color: Colors.white70, fontSize: rank == 1 ? 14 : 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.favorite, color: Color(0xFFFF5252), size: 12),
          ],
        ),
      ],
    );
  }

  Widget _buildRankCard(Map<String, dynamic> user, int rank, {bool isFloating = false}) {
    final isMe = user['id'] == _supabase.auth.currentUser?.id;
    final isHighlighted = isMe || isFloating;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isHighlighted ? EventzoneTheme.primaryAction : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isHighlighted ? EventzoneTheme.primaryAction : Colors.white12),
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#$rank',
                style: TextStyle(color: isHighlighted ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundImage: _getAvatarProvider(user['avatar_url']),
              child: _getAvatarProvider(user['avatar_url']) == null ? Text(user['full_name']?[0] ?? '?') : null,
            ),
          ],
        ),
        title: Text(isMe ? 'You' : (user['full_name'] ?? 'Unknown'), style: TextStyle(color: Colors.white, fontWeight: isMe ? FontWeight.bold : FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${user['connection_count']}',
              style: TextStyle(color: isHighlighted ? Colors.white : Colors.white70, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.favorite, color: Color(0xFFFF5252), size: 16),
          ],
        ),
      ),
    );
  }

  // --- ANALYTICS TAB ---

  Widget _buildAnalyticsTab() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: EventzoneTheme.primaryAction,
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 24),
          _buildActivityChart(),
          const SizedBox(height: 24),
          _buildSourceDonutChart(),
          const SizedBox(height: 24),
          _buildScannedVsScannedYouChart(),
          const SizedBox(height: 24),
          _buildTimeOfDayChart(),
          const SizedBox(height: 24),
          _buildTopCompaniesChart(),
          const SizedBox(height: 24),
          _buildDemographicsChart(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    int total = _myConnections.length;
    int scanned = _myConnections.where((c) => c['source'] == 'scan').length;
    int manual = total - scanned;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Connections',
            total.toString(),
            LucideIcons.users,
            EventzoneTheme.primaryAction,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Scanned (QR)',
            scanned.toString(),
            LucideIcons.scanLine,
            Colors.greenAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildActivityChart() {
    // Group connections by day for the last 7 days
    final now = DateTime.now();
    final Map<int, int> connectionsByDay = { for (var i = 0; i < 7; i++) i: 0 };
    
    for (var conn in _myConnections) {
      if (conn['created_at'] != null) {
        final date = DateTime.parse(conn['created_at']).toLocal();
        final diff = now.difference(date).inDays;
        if (diff >= 0 && diff < 7) {
          connectionsByDay[diff] = (connectionsByDay[diff] ?? 0) + 1;
        }
      }
    }

    final spots = connectionsByDay.entries.map((e) {
      return FlSpot(6 - e.key.toDouble(), e.value.toDouble());
    }).toList();

    double maxY = connectionsByDay.values.fold(1.0, (m, v) => v > m ? v.toDouble() : m);
    if (maxY < 5) maxY = 5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Networking Activity (Last 7 Days)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (maxY / 5).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        return Text(value.toInt().toString(), style: const TextStyle(color: Colors.white54, fontSize: 10));
                      },
                      reservedSize: 28,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final date = now.subtract(Duration(days: 6 - value.toInt()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(DateFormat('E').format(date), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY + 1,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: EventzoneTheme.primaryAction,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: EventzoneTheme.primaryAction.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemographicsChart() {
    // Top Titles
    final Map<String, int> titles = {};
    for (var conn in _myConnections) {
      final title = conn['title']?.toString().trim();
      if (title != null && title.isNotEmpty && title.toLowerCase() != 'unknown' && title.toLowerCase() != 'null') {
        titles[title] = (titles[title] ?? 0) + 1;
      }
    }

    if (titles.isEmpty) return const SizedBox();

    final sortedTitles = titles.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sortedTitles.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Connection Roles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          ...top5.map((entry) {
            final percentage = entry.value / _myConnections.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(entry.key, style: const TextStyle(color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('${entry.value}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: Colors.white12,
                    color: EventzoneTheme.accentSuccess,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSourceDonutChart() {
    final Map<String, int> sources = {};
    for (var conn in _myConnections) {
      final source = conn['source']?.toString() ?? 'Manual Entry';
      sources[source] = (sources[source] ?? 0) + 1;
    }

    if (sources.isEmpty) return const SizedBox();

    final colors = [EventzoneTheme.primaryAction, Colors.purpleAccent, Colors.orangeAccent, Colors.greenAccent, Colors.redAccent];
    int colorIndex = 0;
    final sections = sources.entries.map((entry) {
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${entry.value}',
        radius: 40,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contact Sources', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: sections,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sources.entries.map((entry) {
                      final color = colors[sources.keys.toList().indexOf(entry.key) % colors.length];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(entry.key, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannedVsScannedYouChart() {
    int scannedByMe = 0;
    int scannedMe = 0;
    
    // We infer this: if source is 'QR Code' or 'Business Card', it's usually scanned by me.
    // However, for true inbound/outbound, we need the exact direction, but based on current schema,
    // we'll approximate based on reciprocal logic. If source is 'QR Code' and created by me, I scanned. 
    // Wait, since 'connections' only holds my contacts, I can just show the total scans vs manual.
    // Let's do Inbound vs Outbound if we can. Without full directionality, let's use 'Business Card' & 'Event Badge' as scanned by me.
    // Actually, let's do a simple comparison chart of Manual vs Automated networking.
    for (var conn in _myConnections) {
      final s = conn['source']?.toString().toLowerCase() ?? '';
      if (s.contains('qr') || s.contains('badge') || s.contains('card') || s.contains('scan')) {
        scannedByMe++;
      } else {
        scannedMe++;
      }
    }

    if (scannedByMe == 0 && scannedMe == 0) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Scan vs Manual', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildComparisonBar('Scans', scannedByMe, EventzoneTheme.accentSuccess, Icons.qr_code_scanner)),
              const SizedBox(width: 16),
              Expanded(child: _buildComparisonBar('Manual', scannedMe, Colors.orangeAccent, Icons.edit_document)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildComparisonBar(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text('$value', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTimeOfDayChart() {
    final Map<String, int> timeOfDay = {
      'Morning': 0, // 5 AM - 11 AM
      'Afternoon': 0, // 12 PM - 4 PM
      'Evening': 0, // 5 PM - 8 PM
      'Night': 0, // 9 PM - 4 AM
    };

    for (var conn in _myConnections) {
      if (conn['created_at'] != null) {
        final date = DateTime.parse(conn['created_at']).toLocal();
        final hour = date.hour;
        if (hour >= 5 && hour < 12) {
          timeOfDay['Morning'] = timeOfDay['Morning']! + 1;
        } else if (hour >= 12 && hour < 17) {
          timeOfDay['Afternoon'] = timeOfDay['Afternoon']! + 1;
        } else if (hour >= 17 && hour < 21) {
          timeOfDay['Evening'] = timeOfDay['Evening']! + 1;
        } else {
          timeOfDay['Night'] = timeOfDay['Night']! + 1;
        }
      }
    }

    if (timeOfDay.values.every((v) => v == 0)) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Networking Time-of-Day', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: timeOfDay.entries.map((entry) {
              final maxVal = timeOfDay.values.fold(1, (m, v) => v > m ? v : m);
              final height = (entry.value / maxVal) * 80.0;
              return Column(
                children: [
                  Text('${entry.value}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    width: 30,
                    height: height == 0 ? 4 : height,
                    decoration: BoxDecoration(
                      color: EventzoneTheme.primaryAction,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(entry.key.substring(0, 3), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCompaniesChart() {
    final Map<String, int> companies = {};
    for (var conn in _myConnections) {
      final company = conn['company']?.toString().trim();
      if (company != null && company.isNotEmpty && company.toLowerCase() != 'unknown' && company.toLowerCase() != 'null') {
        companies[company] = (companies[company] ?? 0) + 1;
      }
    }

    if (companies.isEmpty) return const SizedBox();

    final sortedCompanies = companies.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sortedCompanies.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Companies', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          ...top5.map((entry) {
            final percentage = entry.value / _myConnections.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(entry.key, style: const TextStyle(color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('${entry.value}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: Colors.white12,
                    color: Colors.purpleAccent,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
