import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/profile_material_finish.dart';

class MaterialFinishSelector extends StatelessWidget {
  final ProfileMaterialFinish selectedFinish;
  final ValueChanged<ProfileMaterialFinish> onFinishChanged;

  const MaterialFinishSelector({
    super.key,
    required this.selectedFinish,
    required this.onFinishChanged,
  });

  @override
  Widget build(BuildContext context) {
    final finishes = ProfileMaterialFinish.all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0, left: 2.0),
          child: Text(
            "SELECT MATERIAL FINISH",
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: finishes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 54,
          ),
          itemBuilder: (context, index) {
            final finish = finishes[index];
            final bool isSelected = finish.id == selectedFinish.id;

            return _buildFinishCard(context, finish, isSelected);
          },
        ),
      ],
    );
  }

  Widget _buildFinishCard(
    BuildContext context,
    ProfileMaterialFinish finish,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onFinishChanged(finish);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? finish.primaryColor.withOpacity(0.14)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? finish.primaryColor
                : Colors.white.withOpacity(0.12),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: finish.glowColor,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                    spreadRadius: -2,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Color Dot
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: finish.dotColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(finish.type == ProfileMaterialFinishType.obsidianMatte ? 0.3 : 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: finish.dotColor.withOpacity(0.45),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Finish Title
            Expanded(
              child: Text(
                finish.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? finish.accentColor : Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
