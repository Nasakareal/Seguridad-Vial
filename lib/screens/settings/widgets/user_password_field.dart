import 'package:flutter/material.dart';

class UserPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;

  const UserPasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
  });

  @override
  State<UserPasswordField> createState() => _UserPasswordFieldState();
}

class _UserPasswordFieldState extends State<UserPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      obscureText: _obscure,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: widget.label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
        ),
      ),
    );
  }
}
