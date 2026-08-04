import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/eventzone_theme.dart';
import '../widgets/glass_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_detail_screen.dart';
import '../providers/connection_providers.dart';
import '../utils/avatar_helper.dart';
import '../utils/social_link_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';
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
  bool _isLoadingProfile = true;

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
  }

  void _fetchInitialProfile() async {
    if (widget.targetUserId == null) {
      setState(() => _isLoadingProfile = false);
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
        });
      }
    } catch (e) {
      debugPrint("Error fetching initial profile: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
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
        return FontAwesomeIcons.linkedin;
      case 'instagram':
        return FontAwesomeIcons.instagram;
      case 'x':
      case 'twitter':
        return FontAwesomeIcons.xTwitter;
      case 'facebook':
        return FontAwesomeIcons.facebook;
      case 'website':
      case 'company_website':
        return LucideIcons.globe;
      case 'whatsapp':
        return FontAwesomeIcons.whatsapp;
      case 'github':
        return FontAwesomeIcons.github;
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
    
    // 1. Fetch from SharedPreferences first
    List<String>? savedTags = prefs.getStringList('user_global_tags');
    
    if (savedTags != null) {
      existingTags = savedTags;
    } else {
      // 2. Fallback to migration from Supabase connections (only runs once if empty)
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
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                    SizedBox(height: 32),
                    Text(
                      "Add Tag".tr(),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Organize your connections with custom tags".tr(),
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                    SizedBox(height: 32),
                    TextField(
                      controller: textController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Enter tag name (e.g. Designer, Investor)".tr(),
                        hintStyle: TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      autofocus: true,
                    ),
                    if (existingTags.isNotEmpty) ...[
                      SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Recent Tags".tr(), style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: existingTags.map((tag) => Container(
                            padding: EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
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
                                    padding: EdgeInsets.only(right: 4.0),
                                    child: Text(tag, style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => deleteTagFromGlobal(tag),
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.close, size: 12, color: Colors.white54),
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                    ],
                    SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: Text("Cancel".tr(), style: TextStyle(color: Colors.white38, fontSize: 16)),
                          ),
                        ),
                        SizedBox(width: 16),
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
                              backgroundColor: EventzoneTheme.primaryAction,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: Text("Add".tr(), style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                SizedBox(height: 32),
                Text(
                  "Connection Note".tr(),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                ),
                SizedBox(height: 8),
                Text(
                  "Write down a memorable reminder...".tr(),
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
                SizedBox(height: 32),
                TextField(
                  controller: textController,
                  maxLines: 4,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Enter your notes here...".tr(),
                    hintStyle: TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  autofocus: true,
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: Text("Cancel".tr(), style: TextStyle(color: Colors.white38, fontSize: 16)),
                      ),
                    ),
                    SizedBox(width: 16),
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
                          backgroundColor: EventzoneTheme.primaryAction,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: Text("Save".tr(), style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
      backgroundColor: Color(0xFF0C0F1A),
      shape: RoundedRectangleBorder(
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
                    Text("Edit Connection Details".tr(), style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 20),
                    
                    // Avatar Upload section
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
                              child: currentAvatarUrl.isEmpty ? Icon(LucideIcons.user, size: 40, color: Colors.white38) : null,
                            ),
                            if (isUploadingImage)
                              CircularProgressIndicator(color: EventzoneTheme.primaryAction)
                            else
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: EventzoneTheme.primaryAction,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(LucideIcons.camera, size: 14, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    
                    _buildField("Name", nameCtrl),
                    _buildField("Job Title".tr(), titleCtrl),
                    _buildField("Company".tr(), companyCtrl),
                    _buildField("Department", deptCtrl),
                    _buildField("Email".tr(), emailCtrl),
                    _buildField("Phone", phoneCtrl),
                    _buildField("Website", webCtrl),
                    _buildField("Address".tr(), addressCtrl),
                    SizedBox(height: 24),
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
                      backgroundColor: EventzoneTheme.primaryAction,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text("Save Changes".tr(), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
      padding: EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          TextField(
            controller: controller,
            style: TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white10,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF0F1322),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(LucideIcons.trash2, color: Colors.redAccent),
                title: Text("Delete Connection".tr(), style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteConnection();
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.share2, color: Colors.white),
                title: Text("Share Connection".tr(), style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Connection details copied to clipboard!".tr())),
                  );
                },
              ),
              SizedBox(height: 12),
            ],
          ),
        );
      },
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
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                SizedBox(height: 32),
                Text(
                  "Delete Contact".tr(),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                ),
                SizedBox(height: 16),
                Text(
                  "delete_contact_prompt".tr(args: [_name]),
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Cancel".tr(), style: TextStyle(color: Colors.white38, fontSize: 16)),
                      ),
                    ),
                    SizedBox(width: 16),
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
                            Navigator.pop(context); // Go back to Network list
                          } catch (e) {
                            debugPrint("Error deleting: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text("Delete".tr(), style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.lock, color: EventzoneTheme.primaryAction, size: 28),
          ),
          SizedBox(height: 16),
          Text(
            "Connect to view full profile".tr(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Unlock email, phone number, notes, and other professional card details.".tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
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
        sourceColor = Colors.purpleAccent;
        break;
      case 'qr code':
        sourceIcon = LucideIcons.qrCode;
        sourceColor = EventzoneTheme.primaryAction;
        break;
      case 'manual entry':
      default:
        sourceIcon = LucideIcons.fileText;
        sourceColor = Colors.cyanAccent;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: sourceColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sourceColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(sourceIcon, color: sourceColor, size: 14),
          SizedBox(width: 6),
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
      return SizedBox.shrink();
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
          icon: Icon(LucideIcons.messageSquare, size: 16),
          label: Text("Message".tr(), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: EventzoneTheme.primaryAction,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final service = ref.read(supabaseServiceProvider);
            final success = await service.connectDirectly(widget.targetUserId!);
            if (success) {
              ref.invalidate(connectionStatusProvider(widget.targetUserId!));
              messenger.showSnackBar(
                SnackBar(
                  content: Text("Connected with $_name!"),
                  backgroundColor: EventzoneTheme.accentSuccess,
                ),
              );
            } else {
              messenger.showSnackBar(
                SnackBar(
                  content: Text("Failed to connect.".tr()),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          icon: Icon(LucideIcons.userPlus, size: 16),
          label: Text("Connect".tr(), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: EventzoneTheme.primaryAction,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine connection status
    String connectionStatus = 'accepted';
    if (widget.connectionId != null) {
      connectionStatus = 'accepted';
    } else if (widget.targetUserId != null) {
      final statusAsync = ref.watch(connectionStatusProvider(widget.targetUserId!));
      connectionStatus = statusAsync.value ?? 'none';
    }
    final bool isConnected = connectionStatus == 'accepted';

    return Scaffold(
      backgroundColor: Color(0xFF060913),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Large Profile Image Header
                  Stack(
                    children: [
                      Container(
                        height: 320,
                        width: double.infinity,
                        color: Color(0xFF0F1322),
                        child: getAvatarProvider(widget.avatarUrl) == null
                            ? Center(
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
                              Colors.transparent,
                              Color(0xFF060913),
                            ],
                          ),
                        ),
                      ),
                      // Top Buttons Overlays
                      SafeArea(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Icon(LucideIcons.chevronLeft, color: Colors.white, size: 20),
                                ),
                              ),
                              Row(
                                children: [
                                  if (widget.targetUserId == null) ...[
                                    GestureDetector(
                                      onTap: _showEditProfileDialog,
                                      child: Container(
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white10),
                                        ),
                                        child: Icon(LucideIcons.edit3, color: Colors.white, size: 18),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                  ],
                                  if (isConnected || widget.targetUserId == null)
                                    GestureDetector(
                                      onTap: _confirmDeleteConnection,
                                      child: Container(
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white10),
                                        ),
                                        child: Icon(LucideIcons.trash2, color: Colors.redAccent, size: 18),
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
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _name,
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                            ),
                            if (widget.isNew == 'true') ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: EventzoneTheme.primaryAction.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: EventzoneTheme.primaryAction.withOpacity(0.4)),
                                ),
                                child: Text(
                                  "NEW".tr(),
                                  style: TextStyle(color: EventzoneTheme.primaryAction, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          _title,
                          style: TextStyle(fontSize: 15, color: Colors.white70, fontWeight: FontWeight.w500),
                        ),
                        if (_department.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            _department,
                            style: TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.w400),
                          ),
                        ],
                        if (_company.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            _company,
                            style: TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.w400),
                          ),
                        ],
                        SizedBox(height: 16),
                        
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
                                    Icon(LucideIcons.calendar, color: Colors.white38, size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      widget.createdAt != null 
                                          ? _formatDate(widget.createdAt!) 
                                          : "Unknown Date", 
                                      style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        
                        if (_tags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          // Tags Wrap
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
                          // Action Buttons Layer
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
                          // Render dynamic social links (LinkedIn, WhatsApp, GitHub, etc.)
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
                          Text("Notes".tr(), style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          SizedBox(height: 12),
                          if (_parsedNotes.isEmpty) ...[
                            Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(LucideIcons.fileText, color: Colors.white30, size: 24),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      "Write down a memorable reminder about\nyour contact".tr(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
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
                                padding: EdgeInsets.only(bottom: 8.0),
                                child: GlassContainer(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (displayDate.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(bottom: 8.0),
                                          child: Row(
                                            children: [
                                              Icon(LucideIcons.calendar, size: 10, color: Colors.white38),
                                              SizedBox(width: 4),
                                              Text(displayDate, style: TextStyle(color: Colors.white38, fontSize: 10)),
                                            ],
                                          ),
                                        ),
                                      Text(
                                        note['text'] ?? '',
                                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        SizedBox(height: 40),
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
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
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
                          backgroundColor: Color(0xFF131726),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.white10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text("Add tag".tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: _showAddNoteDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF131726),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.white10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text("Add note".tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

  Widget _buildContactRow(IconData icon, String value, String type) {
    return _TappableContactRow(icon: icon, value: value, type: type);
  }

  Widget _buildAboutMeSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("About Me".tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
        SizedBox(height: 16),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCollapsibleBio() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: ExpansionTile(
          title: Text("Professional Bio".tr(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          iconColor: Colors.white54,
          collapsedIconColor: Colors.white54,
          childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _bio,
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
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
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: ExpansionTile(
          title: Text("What I'm Looking For".tr(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          iconColor: Colors.white54,
          collapsedIconColor: Colors.white54,
          childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: _lookingFor.map((item) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: EventzoneTheme.primaryAction.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: EventzoneTheme.primaryAction.withOpacity(0.3)),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(color: EventzoneTheme.primaryAction, fontWeight: FontWeight.w600, fontSize: 13),
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
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: ExpansionTile(
          title: Text("Industries & Interests".tr(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          iconColor: Colors.white54,
          collapsedIconColor: Colors.white54,
          childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: uniqueTags.map((item) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.w600, fontSize: 13),
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

  const _TappableContactRow({
    required this.icon,
    required this.value,
    required this.type,
  });

  @override
  State<_TappableContactRow> createState() => _TappableContactRowState();
}

class _TappableContactRowState extends State<_TappableContactRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = widget.value.trim().isEmpty;
    
    return AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: Duration(milliseconds: 100),
      child: Opacity(
        opacity: isEmpty ? 0.4 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: Color(0x331A73E8), // Electric blue ripple
            highlightColor: Colors.transparent,
            onTapDown: isEmpty ? null : (_) => setState(() => _isPressed = true),
            onTapUp: isEmpty ? null : (_) => setState(() => _isPressed = false),
            onTapCancel: isEmpty ? null : () => setState(() => _isPressed = false),
            onTap: isEmpty ? null : () {
              launchSocialLink(context, widget.type, widget.value);
            },
            child: GlassContainer(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: Colors.white70, size: 16),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.value,
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          widget.type,
                          style: TextStyle(color: Colors.white38, fontSize: 10),
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
