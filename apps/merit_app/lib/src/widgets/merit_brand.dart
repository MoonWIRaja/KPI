import 'package:flutter/material.dart';

class MeritBrand extends StatelessWidget {
  const MeritBrand({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 36 : 42,
            height: compact ? 36 : 42,
            decoration: BoxDecoration(
              color: const Color(0xFF172033),
              borderRadius: BorderRadius.circular(compact ? 10 : 12),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              size: compact ? 21 : 25,
              color: const Color(0xFFFFD166),
              semanticLabel: 'Merit Tracker',
            ),
          ),
          SizedBox(width: compact ? 10 : 12),
          Text(
            'Merit Tracker',
            style: TextStyle(
              fontSize: compact ? 17 : 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: const Color(0xFF172033),
            ),
          ),
        ],
      );
}
