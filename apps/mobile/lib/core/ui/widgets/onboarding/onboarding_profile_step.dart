import 'package:flutter/material.dart';

import 'package:match_point/features/onboarding/models/gender.dart';
import 'package:match_point/core/i18n/app_locale.dart';

class OnboardingProfileStep extends StatelessWidget {
  final TextEditingController displayNameCtrl;
  final DateTime? birthDate;
  final VoidCallback onPickBirthDate;
  final String birthDateLabel;

  /// null = "prefiero no decirlo", que es una respuesta válida y no
  /// bloquea el paso. Se pregunta aquí (y no en el paso de preferencias)
  /// porque es parte de quién eres, no de a quién buscas.
  final Gender? gender;
  final ValueChanged<Gender?> onGenderChanged;

  /// Descripción libre. Antes este campo no existia en ningun sitio: la bio
  /// se rellenaba sola con la frase del "objetivo", asi que solo habia tres
  /// descripciónes posibles en toda la app y ninguna la habia escrito nadie.
  final TextEditingController bioCtrl;

  final VoidCallback? onNameSubmitted;

  const OnboardingProfileStep({
    super.key,
    required this.displayNameCtrl,
    required this.birthDate,
    required this.onPickBirthDate,
    required this.birthDateLabel,
    required this.gender,
    required this.onGenderChanged,
    required this.bioCtrl,
    this.onNameSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.current.yourProfileStep, style: t.headlineMedium),
          const SizedBox(height: 8),


          TextField(
            controller: displayNameCtrl,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => onNameSubmitted?.call(),
            decoration: InputDecoration(labelText: S.current.displayName),
          ),
          const SizedBox(height: 12),

          InkWell(
            onTap: onPickBirthDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: S.current.birthDate,
                border: OutlineInputBorder(),
              ),
              child: Text(birthDateLabel),
            ),
          ),

          const SizedBox(height: 24),

          Text(S.current.gender, style: t.titleMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final option in Gender.values)
                ChoiceChip(
                  label: Text(option.label),
                  selected: gender == option,
                  // Volver a tocar el que ya está elegido lo deselecciona:
                  // es la única forma de volver a "prefiero no decirlo"
                  // sin añadir un cuarto chip que diga eso mismo.
                  onSelected: (selected) =>
                      onGenderChanged(selected ? option : null),
                ),
            ],
          ),

          const SizedBox(height: 28),

          Text(S.current.aboutYou, style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            S.current.aboutYouHint,
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bioCtrl,
            // Varias lineas y sin tope visible: el limite real (500) lo
            // valida el backend, y un contador permanente debajo del campo
            // es ruido — mismo criterio que el resto de campos de texto.
            maxLines: 4,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: S.current.bioExample,
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}
