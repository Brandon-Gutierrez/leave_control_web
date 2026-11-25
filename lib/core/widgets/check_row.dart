import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Una opción con su casilla cuadrada: marcada va en negro y en negrita. Sirve
/// para elegir varias cosas de una lista (los motivos de un predio).
/// Con [onTap] nulo queda deshabilitada.
class CheckRow extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback? onTap;

  const CheckRow({
    super.key,
    required this.label,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: checked ? AppColors.darkText : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: checked
                        ? null
                        : Border.all(
                            color: const Color(0xFFBDBDB8),
                            width: 1.5,
                          ),
                  ),
                  child: checked
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: checked ? FontWeight.w700 : FontWeight.w500,
                      color: checked ? AppColors.darkText : AppColors.muted,
                    ),
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
