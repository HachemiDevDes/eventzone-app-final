import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/eventzone_theme.dart';
import '../theme/profile_material_finish.dart';
import '../widgets/glass_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_detail_screen.dart';
import '../providers/connection_providers.dart';
import '../utils/avatar_helper.dart';
import '../utils/social_link_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/event_model.dart';
import '../services/supabase_service.dart';
import 'event_details_screen.dart';

class ProfessionalProfileScreen extends ConsumerStatefulWidget {
  final String name;
  final String title;
  final String avatarUrl;
  final String? source;
  final String? isNew;
  final String? email;
  final String? phone;
  final String? website;
  final String? company;
  final String? department;
  final String? notes;
  final String? address;
  final List<String>? tags;
  final String? connectionId;
  final String? targetUserId;
  final dynamic socialLinks;
  final String? createdAt;

  const ProfessionalProfileScreen({
    super.key,
    required this.name,
    required this.title,
    required this.avatarUrl,
    this.source,
    this.isNew,
    this.email,
    this.phone,
    this.website,
    this.company,
    this.department,
    this.notes,
    this.address,
    this.tags,
    this.connectionId,
    this.targetUserId,
    this.socialLinks,
    this.createdAt,
  });

  @override
  ConsumerState<ProfessionalProfileScreen> createState() => _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState extends ConsumerState<ProfessionalProfileScreen> {
  late String _notes;
  List<Map<String, dynamic>> _parsedNotes = [];
  late List<String> _tags;
  late String _email;
  late String _phone;
  late String _website;
  late String _company;
  late String _department;
  late String _address;
  late String _name;
  late String _title;
  late String _avatarUrl;
  late List<Map<String, dynamic>> _socialLinks;
  RealtimeChannel? _profileChannel;

  String _bio = "";
  List<String> _lookingFor = [];
  List<String> _industries = [];
  List<String> _interests = [];
  ProfileMaterialFinish _finish = ProfileMaterialFinish.titaniumCobalt;

  List<Map<String, dynamic>> _parseSocialLinks(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (raw is Map) {
      return raw.entries.map((e) => {
        'platform': e.key.toString(),
        'value': e.value.toString(),
        'label': e.value.toString()
      }).toList();
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    _notes = widget.notes ?? "";
    
    try {
      if (_notes.startsWith('[')) {
        final List<dynamic> decoded = jsonDecode(_notes);
        _parsedNotes = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (_notes.isNotEmpty) {
        _parsedNotes = [
          {
            "text": _notes,
            "date": widget.createdAt ?? DateTime.now().toIso8601String()
          }
        ];
      }
    } catch (e) {
      if (_notes.isNotEmpty) {
        _parsedNotes = [
          {
            "text": _notes,
            "date": widget.createdAt ?? DateTime.now().toIso8601String()
          }
        ];
      }
    }
    _tags = widget.tags ?? [];
    _email = widget.email ?? "";
    _phone = widget.phone ?? "";
    _website = widget.website ?? "";
    _company = widget.company ?? "";
    _department = widget.department ?? "";
    _address = widget.address ?? "";
    _name = widget.name;
    _title = widget.title.replaceAll(' @', ' @');
    _avatarUrl = widget.avatarUrl;
    _socialLinks = _parseSocialLinks(widget.socialLinks);
    _fetchInitialProfile();
    _subscribeToProfileUpdates();
    _markAsNotNew();
    _loadAttendingEvents();
  }

  List<EventModel> _attendingEvents = [];
  bool _isLoadingEvents = false;

  Future<void> _loadAttendingEvents() async {
    if (widget.targetUserId == null) return;
    setState(() => _isLoadingEvents = true);
    try {
      final service = SupabaseService();
      final events = await service.fetchAttendingEventsForUser(widget.targetUserId!);
      if (mounted) {
        setState(() {
          _attendingEvents = events;
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading attending events for user: $e");
      if (mounted) setState(() => _isLoadingEvents = false);
    }
  }

  void _fetchInitialProfile() async {
    if (widget.targetUserId == null) {
      return;
    }
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', widget.targetUserId!)
          .maybeSingle();

      if (profile != null && mounted) {
        setState(() {
          _name = profile['full_name'] ?? _name;
          final String job = profile['job_title'] ?? '';
          final String comp = profile['company_name'] ?? '';
          _title = job.isNotEmpty
              ? (comp.isNotEmpty ? "$job at $comp" : job)
              : (comp.isNotEmpty ? "Professional at $comp" : "Attendee");
          _company = comp.isNotEmpty ? comp : _company;
          _department = profile['department'] ?? _department;
          _address = profile['address'] ?? _address;
          _bio = profile['bio'] ?? '';
          
          final lookingForStr = profile['what_im_looking_for'] as String?;
          if (lookingForStr != null && lookingForStr.isNotEmpty) {
            _lookingFor = lookingForStr.split(',').map((e) => e.trim()).toList();
          }
          
          _industries = (profile['industries'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          _interests = (profile['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          
          final meta = profile['metadata'] as Map<String, dynamic>?;
          _phone = profile['phone'] as String? ?? meta?['phone'] as String? ?? _phone;
          _website = profile['website'] as String? ?? meta?['website'] as String? ?? _website;
          
          if (meta?['socials'] != null) {
            _socialLinks = _parseSocialLinks(meta?['socials']);
          } else if (profile['social_links'] != null) {
            _socialLinks = _parseSocialLinks(profile['social_links']);
          }
          _finish = ProfileMaterialFinish.fromProfile(profile);
        });
      }
    } catch (e) {
      debugPrint("Error fetching initial profile: $e");
    }
  }

  void _markAsNotNew() async {
    if (widget.isNew == 'true' && widget.connectionId != null) {
      try {
        await Supabase.instance.client
            .from('connections')
            .update({'is_new': false})
            .eq('id', widget.connectionId!);
      } catch (e) {
        debugPrint("Error marking as not new: $e");
      }
    }
  }

  @override
  void dispose() {
    _profileChannel?.unsubscribe();
    super.dispose();
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final List<String> months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
      final month = months[dt.month - 1];
      final day = dt.day.toString().padLeft(2, '0');
      
      int hour = dt.hour;
      final String ampm = hour >= 12 ? 'PM' : 'AM';
      hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      
      return "$day $month ${dt.year} $hour:$minute $ampm";
    } catch (_) {
      return isoString;
    }
  }

  void _subscribeToProfileUpdates() {
    if (widget.targetUserId == null) return;
    _profileChannel = Supabase.instance.client
        .channel('profile_detail_${widget.targetUserId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.targetUserId!,
          ),
          callback: (payload) {
            final live = payload.newRecord;
            if (mounted) {
              setState(() {
                _name = live['full_name'] ?? _name;
                final String job = live['job_title'] ?? '';
                final String comp = live['company_name'] ?? '';
                _title = job.isNotEmpty
                    ? (comp.isNotEmpty ? "$job at $comp" : job)
                    : (comp.isNotEmpty ? "Professional at $comp" : "Attendee");
                _company = comp.isNotEmpty ? comp : _company;
                _department = live['department'] ?? _department;
                _address = live['address'] ?? _address;
                
                final meta = live['metadata'] as Map<String, dynamic>?;
                _phone = live['phone'] as String? ?? meta?['phone'] as String? ?? _phone;
                _website = live['website'] as String? ?? meta?['website'] as String? ?? _website;
                
                if (meta?['socials'] != null) {
                  _socialLinks = _parseSocialLinks(meta?['socials']);
                } else if (live['social_links'] != null) {
                  _socialLinks = _parseSocialLinks(live['social_links']);
                }
                _finish = ProfileMaterialFinish.fromProfile(live);
              });
            }
          },
        )
        .subscribe();
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'phone':
      case 'phone_number':
        return LucideIcons.phone;
      case 'email':
        return LucideIcons.mail;
      case 'linkedin':
        return FontAwesomeIcons.linkedin.data;
      case 'instagram':
        return FontAwesomeIcons.instagram.data;
      case 'x':
      case 'twitter':
        return FontAwesomeIcons.xTwitter.data;
      case 'facebook':
        return FontAwesomeIcons.facebook.data;
      case 'website':
      case 'company_website':
        return LucideIcons.globe;
      case 'whatsapp':
        return FontAwesomeIcons.whatsapp.data;
      case 'github':
        return FontAwesomeIcons.github.data;
      default:
        return LucideIcons.link;
    }
  }

  Future<void> _updateFieldInSupabase(String column, dynamic value) async {
    if (widget.connectionId == null) return;
    try {
      await Supabase.instance.client
          .from('connections')
          .update({column: value})
          .eq('id', widget.connectionId!);
    } catch (e) {
      debugPrint("Error updating $column: $e");
    }
  }

  void _showAddTagDialog() async {
    final textController = TextEditingController();
    List<String> existingTags = [];
    final prefs = await SharedPreferences.getInstance();
    
    List<String>? savedTags = prefs.getStringList('user_global_tags');
    
    if (savedTags != null) {
      existingTags = savedTags;
    } else {
      try {
        final res = await Supabase.instance.client
            .from('connections')
            .select('tags')
            .eq('user_id', Supabase.instance.client.auth.currentUser!.id);
        
        final Set<String> uniqueTags = {};
        for (var row in res) {
          if (row['tags'] != null) {
            if (row['tags'] is List) {
              uniqueTags.addAll((row['tags'] as List).map((e) => e.toString()));
            } else if (row['tags'] is String) {
              uniqueTags.add(row['tags'].toString());
            }
          }
        }
        existingTags = uniqueTags.toList()..sort();
        await prefs.setStringList('user_global_tags', existingTags);
      } catch (e) {
        debugPrint('Error fetching tags: $e');
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void saveTagToGlobal(String newTag) {
              if (!existingTags.contains(newTag)) {
                setModalState(() {
                  existingTags.add(newTag);
                  existingTags.sort();
                });
                prefs.setStringList('user_global_tags', existingTags);
              }
            }

            void deleteTagFromGlobal(String tag) {
              setModalState(() {
                existingTags.remove(tag);
              });
              prefs.setStringList('user_global_tags', existingTags);
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: GlassContainer(
                borderRadius: 32,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      "Add Tag".tr(),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Organize your connections with custom tags".tr(),
                      style: const TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Enter tag name (e.g. Designer, Investor)".tr(),
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      autofocus: true,
                    ),
                    if (existingTags.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Recent Tags".tr(), style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: existingTags.map((tag) => Container(
                            padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (!_tags.contains(tag)) {
                                      setState(() {
                                        _tags.add(tag);
                                      });
                                      _updateFieldInSupabase('tags', _tags);
                                    }
                                    Navigator.pop(context);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 4.0),
                                    child: Text(tag, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => deleteTagFromGlobal(tag),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 12, color: Colors.white54),
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: Text("Cancel".tr(), style: const TextStyle(color: Colors.white38, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final tag = textController.text.trim();
                              if (tag.isNotEmpty) {
                                saveTagToGlobal(tag);
                                if (!_tags.contains(tag)) {
                                  setState(() {
                                    _tags.add(tag);
                                  });
                                  _updateFieldInSupabase('tags', _tags);
                                }
                              }
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _finish.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: Text("Add".tr(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  void _showAddNoteDialog() {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: GlassContainer(
            borderRadius: 32,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  "Connection Note".tr(),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Write down a memorable reminder...".tr(),
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: textController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Enter your notes here...".tr(),
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: Text("Cancel".tr(), style: const TextStyle(color: Colors.white38, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final noteText = textController.text.trim();
                          if (noteText.isNotEmpty) {
                            setState(() {
                              _parsedNotes.insert(0, {
                                "text": noteText,
                                "date": DateTime.now().toIso8601String(),
                              });
                              _notes = jsonEncode(_parsedNotes);
                            });
                            _updateFieldInSupabase('notes', _notes);
                          }
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _finish.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: Text("Save".tr(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _name);
    final titleCtrl = TextEditingController(text: _title);
    final companyCtrl = TextEditingController(text: _company);
    final deptCtrl = TextEditingController(text: _department);
    final emailCtrl = TextEditingController(text: _email);
    final phoneCtrl = TextEditingController(text: _phone);
    final webCtrl = TextEditingController(text: _website);
    final addressCtrl = TextEditingController(text: _address);
    String currentAvatarUrl = _avatarUrl;
    bool isUploadingImage = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C0F1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Edit Connection Details".tr(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 300, maxHeight: 300, imageQuality: 70);
                          if (image != null) {
                            setModalState(() { isUploadingImage = true; });
                            try {
                              final bytes = await image.readAsBytes();
                              setModalState(() {
                                currentAvatarUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                              });
                            } catch (e) {
                              debugPrint("Error picking image: $e");
                            } finally {
                              setModalState(() { isUploadingImage = false; });
                            }
                          }
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white10,
                              backgroundImage: getAvatarProvider(currentAvatarUrl),
                              child: currentAvatarUrl.isEmpty ? const Icon(LucideIcons.user, size: 40, color: Colors.white38) : null,
                            ),
                            if (isUploadingImage)
                              CircularProgressIndicator(color: _finish.primaryColor)
                            else
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _finish.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(LucideIcons.camera, size: 14, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    _buildField("Name", nameCtrl),
                    _buildField("Job Title".tr(), titleCtrl),
                    _buildField("Company".tr(), companyCtrl),
                    _buildField("Department", deptCtrl),
                    _buildField("Email".tr(), emailCtrl),
                    _buildField("Phone", phoneCtrl),
                    _buildField("Website", webCtrl),
                    _buildField("Address".tr(), addressCtrl),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _name = nameCtrl.text.trim();
                            _title = titleCtrl.text.trim();
                            _company = companyCtrl.text.trim();
                            _department = deptCtrl.text.trim();
                            _email = emailCtrl.text.trim();
                            _phone = phoneCtrl.text.trim();
                            _website = webCtrl.text.trim();
                            _address = addressCtrl.text.trim();
                            _avatarUrl = currentAvatarUrl;
                          });
                          if (widget.connectionId != null) {
                            Supabase.instance.client.from('connections').update({
                              'name': _name,
                              'title': _title,
                              'company': _company,
                              'department': _department,
                              'email': _email,
                              'phone': _phone,
                              'website': _website,
                              'address': _address,
                              'avatar_url': _avatarUrl,
                            }).eq('id', widget.connectionId!).then((_) {});
                          }
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _finish.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text("Save Changes".tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white10,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteConnection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: GlassContainer(
            borderRadius: 32,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  "Delete Contact".tr(),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  "delete_contact_prompt".tr(args: [_name]),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Cancel".tr(), style: const TextStyle(color: Colors.white38, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            if (widget.connectionId != null) {
                              await Supabase.instance.client
                                  .from('connections')
                                  .delete()
                                  .eq('id', widget.connectionId!);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Deleted $_name!"),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            Navigator.pop(context);
                          } catch (e) {
                            debugPrint("Error deleting: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text("Delete".tr(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLockedOverlay() {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.lock, color: _finish.primaryColor, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            "Connect to view full profile".tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Unlock email, phone number, notes, and other professional card details.".tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge(String source) {
    IconData sourceIcon;
    Color sourceColor;
    switch (source.toLowerCase()) {
      case 'business card':
        sourceIcon = LucideIcons.creditCard;
        sourceColor = Colors.orangeAccent;
        break;
      case 'event badge':
        sourceIcon = LucideIcons.contact;
        sourceColor = const Color(0xFF38BDF8);
        break;
      case 'qr code':
      case 'qr':
        sourceIcon = LucideIcons.qrCode;
        sourceColor = _finish.primaryColor;
        break;
      case 'attendee_portal':
      case 'attendee portal':
        sourceIcon = LucideIcons.globe;
        sourceColor = Colors.blueAccent;
        break;
      case 'manual entry':
      default:
        sourceIcon = LucideIcons.fileText;
        sourceColor = Colors.cyanAccent;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: sourceColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sourceColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(sourceIcon, color: sourceColor, size: 14),
          const SizedBox(width: 6),
          Text(
            "scanned_via".tr(args: [source.toString().tr()]),
            style: TextStyle(
              color: sourceColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCTA(String status) {
    if (widget.source == 'Business Card' || widget.source == 'Event Badge' || widget.source == 'Manual Entry') {
      return const SizedBox.shrink();
    }
    
    if (status == 'accepted') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatDetailScreen(
                  contactName: _name,
                  avatarUrl: widget.avatarUrl,
                  recipientEmail: _email,
                  recipientId: widget.targetUserId,
                ),
              ),
            );
          },
          icon: const Icon(LucideIcons.messageSquare, size: 16),
          label: Text("Message".tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _finish.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
      );
    } else if (status == 'pending_sent') {
      return Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.clock, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    "Request Sent".tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () async {
              if (widget.targetUserId == null) return;
              final messenger = ScaffoldMessenger.of(context);
              final service = ref.read(supabaseServiceProvider);
              final sentList = await service.fetchSentConnectionRequests();
              final matching = sentList.where((r) => r.receiverId == widget.targetUserId).toList();
              if (matching.isNotEmpty) {
                await service.cancelSentConnectionRequest(matching.first.id);
              }
              ref.invalidate(connectionStatusProvider(widget.targetUserId!));
              messenger.showSnackBar(
                const SnackBar(
                  content: Text("Request cancelled"),
                  backgroundColor: Colors.white24,
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("Cancel".tr()),
          ),
        ],
      );
    } else if (status == 'pending_received') {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (widget.targetUserId == null) return;
                final messenger = ScaffoldMessenger.of(context);
                final service = ref.read(supabaseServiceProvider);
                final incomingList = await service.fetchIncomingConnectionRequests();
                final matching = incomingList.where((r) => r.senderId == widget.targetUserId).toList();
                bool success = false;
                if (matching.isNotEmpty) {
                  success = await service.acceptConnectionRequest(matching.first.id, widget.targetUserId!);
                } else {
                  success = await service.sendConnectionRequest(widget.targetUserId!);
                }
                if (success) {
                  ref.invalidate(connectionStatusProvider(widget.targetUserId!));
                  ref.invalidate(incomingRequestsCountProvider);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text("Connected with $_name! Added to contacts."),
                      backgroundColor: EventzoneTheme.accentSuccess,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Failed to accept request. Please try again."),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              icon: const Icon(LucideIcons.check, size: 16),
              label: Text("Accept Request".tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: EventzoneTheme.accentSuccess,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              onPressed: () async {
                if (widget.targetUserId == null) return;
                final messenger = ScaffoldMessenger.of(context);
                final service = ref.read(supabaseServiceProvider);
                final incomingList = await service.fetchIncomingConnectionRequests();
                final matching = incomingList.where((r) => r.senderId == widget.targetUserId).toList();
                if (matching.isNotEmpty) {
                  await service.declineConnectionRequest(matching.first.id);
                }
                ref.invalidate(connectionStatusProvider(widget.targetUserId!));
                ref.invalidate(incomingRequestsCountProvider);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text("Request declined"),
                    backgroundColor: Colors.white24,
                  ),
                );
              },
              icon: const Icon(LucideIcons.x, size: 16),
              label: Text("Decline".tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            if (widget.targetUserId == null) return;
            final messenger = ScaffoldMessenger.of(context);
            final service = ref.read(supabaseServiceProvider);
            final success = await service.sendConnectionRequest(widget.targetUserId!);
            if (success) {
              ref.invalidate(connectionStatusProvider(widget.targetUserId!));
              messenger.showSnackBar(
                SnackBar(
                  content: Text("Connection request sent to $_name!"),
                  backgroundColor: EventzoneTheme.primaryAction,
                ),
              );
            } else {
              messenger.showSnackBar(
                SnackBar(
                  content: Text("Failed to send request.".tr()),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          icon: const Icon(LucideIcons.userPlus, size: 16),
          label: Text("Connect".tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _finish.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String connectionStatus = 'none';
    if (widget.targetUserId != null) {
      final statusAsync = ref.watch(connectionStatusProvider(widget.targetUserId!));
      connectionStatus = statusAsync.value ?? (widget.connectionId != null ? 'accepted' : 'none');
    } else if (widget.connectionId != null) {
      connectionStatus = 'accepted';
    }
    final bool isConnected = connectionStatus == 'accepted';

    return Scaffold(
      backgroundColor: const Color(0xFF060913),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Large Profile Image Header with Material Finish Glow
                  Stack(
                    children: [
                      Container(
                        height: 320,
                        width: double.infinity,
                        color: _finish.cardSurfaceColor,
                        child: getAvatarProvider(widget.avatarUrl) == null
                            ? const Center(
                                child: Icon(
                                  LucideIcons.user,
                                  size: 100,
                                  color: Colors.white24,
                                ),
                              )
                            : Image(
                                image: getAvatarProvider(widget.avatarUrl)!,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Container(
                        height: 320,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black54,
                              _finish.glowColor.withOpacity(0.12),
                              const Color(0xFF060913),
                            ],
                          ),
                        ),
                      ),
                      // Top Buttons Overlays
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: const Icon(LucideIcons.chevronLeft, color: Colors.white, size: 20),
                                ),
                              ),
                              Row(
                                children: [
                                  if (widget.targetUserId == null) ...[
                                    GestureDetector(
                                      onTap: _showEditProfileDialog,
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white10),
                                        ),
                                        child: const Icon(LucideIcons.edit3, color: Colors.white, size: 18),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (isConnected || widget.targetUserId == null)
                                    GestureDetector(
                                      onTap: _confirmDeleteConnection,
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white10),
                                        ),
                                        child: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 18),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 2. Name and Job details section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _name,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                            ),
                            if (widget.isNew == 'true') ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _finish.primaryColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: _finish.primaryColor.withOpacity(0.4)),
                                ),
                                child: Text(
                                  "NEW".tr(),
                                  style: TextStyle(color: _finish.primaryColor, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _title,
                          style: const TextStyle(fontSize: 15, color: Colors.white70, fontWeight: FontWeight.w500),
                        ),
                        if (_department.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _department,
                            style: const TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.w400),
                          ),
                        ],
                        if (_company.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _company,
                            style: const TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.w400),
                          ),
                        ],
                        const SizedBox(height: 16),
                        
                        // Top Info Row (Source Badge + Date)
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (widget.source?.isNotEmpty == true || widget.targetUserId == null)
                                _buildSourceBadge(widget.source?.isNotEmpty == true ? widget.source! : 'Manual Entry'),
                                
                              if (isConnected) 
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.calendar, color: Colors.white38, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.createdAt != null 
                                          ? _formatDate(widget.createdAt!) 
                                          : "Unknown Date", 
                                      style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        
                        if (_tags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ..._tags.map((tag) => Container(
                                padding: const EdgeInsets.only(left: 10, right: 6, top: 5, bottom: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(tag, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _tags.remove(tag);
                                        });
                                        _updateFieldInSupabase('tags', _tags);
                                      },
                                      child: const Icon(LucideIcons.x, size: 12, color: Colors.white54),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ],
                        
                        if (widget.source != 'Business Card' && widget.source != 'Event Badge' && widget.source != 'Manual Entry') ...[
                          const SizedBox(height: 24),
                          _buildConnectionCTA(connectionStatus),
                        ],
                          
                        if (_bio.isNotEmpty || _lookingFor.isNotEmpty || _industries.isNotEmpty || _interests.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            child: SizedBox(
                              width: double.infinity,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("About Me".tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                                  const SizedBox(height: 16),
                                  if (_bio.isNotEmpty) _buildCollapsibleBio(),
                                  if (_lookingFor.isNotEmpty) _buildCollapsibleLookingFor(),
                                  if (_industries.isNotEmpty || _interests.isNotEmpty) _buildCollapsibleIndustriesAndInterests(),
                                ],
                              ),
                            ),
                          ),
                        ],
                          
                        if (!isConnected) ...[
                          const SizedBox(height: 16),
                          _buildLockedOverlay(),
                        ],

                        if (_socialLinks.where((link) => (link['value'] ?? '').toString().trim().isNotEmpty).isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ..._socialLinks
                              .where((link) => (link['value'] ?? '').toString().trim().isNotEmpty)
                              .map((link) {
                                final platform = (link['platform'] ?? '').toString();
                                final val = (link['value'] ?? '').toString().trim();
                                final customLabel = (link['label'] ?? '').toString().trim();
                                final displayPlatform = customLabel.isNotEmpty 
                                    ? customLabel 
                                    : (platform.isNotEmpty
                                        ? platform[0].toUpperCase() + platform.substring(1)
                                        : "");
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _buildContactRow(_getPlatformIcon(platform), val, displayPlatform),
                                );
                              }),
                        ],
                          
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 16),

                        // 5. Notes Section
                        Text("Notes".tr(), style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 12),
                        if (_parsedNotes.isEmpty) ...[
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(LucideIcons.fileText, color: Colors.white30, size: 24),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Write down a memorable reminder about\nyour contact".tr(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          ..._parsedNotes.map((note) {
                            String displayDate = "";
                            if (note['date'] != null) {
                              try {
                                final dt = DateTime.parse(note['date']).toLocal();
                                displayDate = DateFormat('dd MMMM yyyy h:mm a').format(dt);
                              } catch (_) {}
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: GlassContainer(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (displayDate.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: Row(
                                          children: [
                                            const Icon(LucideIcons.calendar, size: 10, color: Colors.white38),
                                            const SizedBox(width: 4),
                                            Text(displayDate, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    Text(
                                      note['text'] ?? '',
                                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                        if (widget.targetUserId != null) ...[
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 16),
                          _buildAttendingEventsSection(),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 6. Bottom Sticky Actions Bar
          if (isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF090C16),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: _showAddTagDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF131726),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.white10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text("Add tag".tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: _showAddNoteDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF131726),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.white10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text("Add note".tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

  Widget _buildAttendingEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.calendarCheck2,
                  size: 16,
                  color: EventzoneTheme.primaryAction,
                ),
                const SizedBox(width: 8),
                Text(
                  "Events Attending".tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            if (_attendingEvents.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: EventzoneTheme.primaryAction.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: EventzoneTheme.primaryAction.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  "${_attendingEvents.length}",
                  style: const TextStyle(
                    color: EventzoneTheme.primaryAction,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingEvents)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: EventzoneTheme.primaryAction,
                ),
              ),
            ),
          )
        else if (_attendingEvents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.calendarX,
                    size: 20,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "No upcoming events scheduled".tr(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Events this attendee registers for will appear here.".tr(),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _attendingEvents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final event = _attendingEvents[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailsScreen(
                        event: event,
                        onRegister: () {},
                        onAccess: () {},
                      ),
                    ),
                  );
                },
                child: GlassContainer(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 16,
                  child: Row(
                    children: [
                      // Event Image Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 72,
                          height: 72,
                          color: Colors.white10,
                          child: event.imageUrl.isNotEmpty
                              ? Image.network(
                                  event.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.white10,
                                    child: const Icon(
                                      LucideIcons.calendar,
                                      color: Colors.white38,
                                      size: 28,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: Colors.white10,
                                  child: const Icon(
                                    LucideIcons.calendar,
                                    color: Colors.white38,
                                    size: 28,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Event Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: EventzoneTheme.primaryAction.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    event.category.toUpperCase(),
                                    style: const TextStyle(
                                      color: EventzoneTheme.primaryAction,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                if (event.isLive) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.circle, color: Colors.redAccent, size: 5),
                                        SizedBox(width: 3),
                                        Text(
                                          "LIVE",
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (event.isJoined) ...[
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: EventzoneTheme.accentSuccess.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: EventzoneTheme.accentSuccess.withOpacity(0.4),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          LucideIcons.check,
                                          size: 10,
                                          color: EventzoneTheme.accentSuccess,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          "You're attending",
                                          style: TextStyle(
                                            color: EventzoneTheme.accentSuccess,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              event.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.calendar,
                                  size: 11,
                                  color: Colors.white54,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    event.date,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (event.location.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    LucideIcons.mapPin,
                                    size: 11,
                                    color: Colors.white38,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      event.location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        LucideIcons.chevronRight,
                        color: Colors.white24,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildContactRow(IconData icon, String value, String type) {
    return _TappableContactRow(icon: icon, value: value, type: type, finishColor: _finish.primaryColor);
  }

  Widget _buildCollapsibleBio() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: ExpansionTile(
          title: Text("Professional Bio".tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          iconColor: Colors.white54,
          collapsedIconColor: Colors.white54,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _bio,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleLookingFor() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: ExpansionTile(
          title: Text("What I'm Looking For".tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          iconColor: Colors.white54,
          collapsedIconColor: Colors.white54,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: _lookingFor.map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _finish.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _finish.primaryColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(color: _finish.primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleIndustriesAndInterests() {
    final uniqueTags = <String>{..._industries, ..._interests}.toList();
    
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: ExpansionTile(
          title: Text("Industries & Interests".tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          iconColor: Colors.white54,
          collapsedIconColor: Colors.white54,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: uniqueTags.map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _finish.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _finish.primaryColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(color: _finish.primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TappableContactRow extends StatefulWidget {
  final IconData icon;
  final String value;
  final String type;
  final Color? finishColor;

  const _TappableContactRow({
    required this.icon,
    required this.value,
    required this.type,
    this.finishColor,
  });

  @override
  State<_TappableContactRow> createState() => _TappableContactRowState();
}

class _TappableContactRowState extends State<_TappableContactRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = widget.value.trim().isEmpty;
    final Color activeColor = widget.finishColor ?? EventzoneTheme.primaryAction;
    
    return AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Opacity(
        opacity: isEmpty ? 0.4 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: activeColor.withOpacity(0.2),
            highlightColor: Colors.transparent,
            onTapDown: isEmpty ? null : (_) => setState(() => _isPressed = true),
            onTapUp: isEmpty ? null : (_) => setState(() => _isPressed = false),
            onTapCancel: isEmpty ? null : () => setState(() => _isPressed = false),
            onTap: isEmpty ? null : () {
              launchSocialLink(context, widget.type, widget.value);
            },
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: Colors.white70, size: 16),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.value,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.type,
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
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
}
