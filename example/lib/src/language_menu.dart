import 'package:flutter/material.dart';

import 'app_strings.dart';

/// App bar menu that switches between the device language, English and
/// Turkish.
class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.translate),
      tooltip: strings.language,
      initialValue: appLocale.value?.languageCode ?? 'system',
      onSelected: (String value) => appLocale.value = value == 'system' ? null : Locale(value),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'system', child: Text(strings.systemLanguage)),
        const PopupMenuItem<String>(value: 'en', child: Text('English')),
        const PopupMenuItem<String>(value: 'tr', child: Text('Türkçe')),
      ],
    );
  }
}
