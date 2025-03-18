import 'package:flutter/material.dart';

abstract class BaseItem extends StatefulWidget {
  final String id;
  final String name;
  final String createdDate;

  const BaseItem({
    super.key,
    required this.id,
    required this.name,
    required this.createdDate,
  });
}
