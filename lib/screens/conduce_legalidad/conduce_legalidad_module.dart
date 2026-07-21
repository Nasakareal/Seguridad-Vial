import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../models/conduce_legalidad.dart';

class ConduceLegalidadModule {
  final String id;
  final String title;
  final String operativoNombre;
  final String listSubtitle;
  final String createRoute;
  final String showRoute;
  final String capturaRoute;
  final String boletaRoute;
  final IconData icon;
  final bool isAlcoholimetria;

  const ConduceLegalidadModule({
    required this.id,
    required this.title,
    required this.operativoNombre,
    required this.listSubtitle,
    required this.createRoute,
    required this.showRoute,
    required this.capturaRoute,
    required this.boletaRoute,
    required this.icon,
    this.isAlcoholimetria = false,
  });

  static const conduceLegalidad = ConduceLegalidadModule(
    id: 'conduce_legalidad',
    title: 'Conduce con legalidad',
    operativoNombre: 'Operativo conduce con legalidad',
    listSubtitle: 'Operativos, capturas y fundamentos',
    createRoute: AppRoutes.conduceLegalidadCreate,
    showRoute: AppRoutes.conduceLegalidadShow,
    capturaRoute: AppRoutes.conduceLegalidadCaptura,
    boletaRoute: AppRoutes.conduceLegalidadBoleta,
    icon: Icons.fact_check_outlined,
  );

  static const alcoholimetria = ConduceLegalidadModule(
    id: 'alcoholimetria',
    title: 'Alcoholimetría',
    operativoNombre: 'Operativo Alcoholimetría',
    listSubtitle: 'Operativos de alcoholimetría y fundamentos de alcohol',
    createRoute: AppRoutes.alcoholimetriaCreate,
    showRoute: AppRoutes.alcoholimetriaShow,
    capturaRoute: AppRoutes.alcoholimetriaCaptura,
    boletaRoute: AppRoutes.alcoholimetriaBoleta,
    icon: Icons.science_outlined,
    isAlcoholimetria: true,
  );

  ConduceLegalidadMeta applyMeta(ConduceLegalidadMeta meta) {
    if (!isAlcoholimetria) return meta;

    final fundamentosAlcohol = _mergeFundamentos([
      ...meta.fundamentosCorralon.where(_isAlcoholFundamento),
      ...meta.fundamentosPersona.where(_isAlcoholFundamento),
    ]);

    return ConduceLegalidadMeta(
      operativoNombre: operativoNombre,
      abilities: meta.abilities,
      fundamentosCorralon: fundamentosAlcohol,
      fundamentosPersona: fundamentosAlcohol,
    );
  }

  bool ownsOperativo(ConduceLegalidadOperativo operativo) {
    final tipo = (operativo.tipoOperativo ?? '').trim().toLowerCase();
    if (tipo == 'alcoholimetria' || tipo == 'conduce_legalidad') {
      return tipo == id;
    }

    final text = _normalize(
      [
        operativo.nombre,
        operativo.objetivo,
        operativo.narrativa,
        operativo.observaciones,
      ].whereType<String>().join(' '),
    );
    final isAlcohol =
        text.contains('ALCOHOL') ||
        text.contains('ALCOHOLEMIA') ||
        text.contains('ALCOHOLIMETRIA');

    return isAlcoholimetria ? isAlcohol : !isAlcohol;
  }

  Map<String, dynamic> operativoPayloadFields() {
    if (!isAlcoholimetria) {
      return const <String, dynamic>{'tipo_operativo': 'conduce_legalidad'};
    }

    return const <String, dynamic>{
      'tipo_operativo': 'alcoholimetria',
      'nombre': 'Operativo Alcoholimetría',
      'objetivo': 'Alcoholimetría',
    };
  }

  int fundamentosCount(ConduceLegalidadMeta? meta) {
    if (meta == null) return 0;
    return {
      ...meta.fundamentosCorralon.map((item) => item.id),
      ...meta.fundamentosPersona.map((item) => item.id),
    }.length;
  }

  bool hasFundamentos(ConduceLegalidadMeta? meta) {
    return fundamentosCount(meta) > 0;
  }

  bool _isAlcoholFundamento(ConduceLegalidadFundamento fundamento) {
    final articulo = (fundamento.articulo ?? '').trim();
    if (articulo == '345' || articulo == '508') return true;

    final text = _normalize(
      [
        fundamento.codigo,
        fundamento.nombre,
        fundamento.etiquetaOperativa,
        fundamento.textoOperativo,
        fundamento.descripcion,
        fundamento.fundamentoLegal,
        fundamento.referenciaLegalCorta,
      ].whereType<String>().join(' '),
    );

    return text.contains('ALCOHOL') ||
        text.contains('ALCOHOLEMIA') ||
        text.contains('EBRIEDAD') ||
        text.contains('EBRIO') ||
        text.contains('INTOXICACION') ||
        text.contains('ALIENTO ALCOHOLICO');
  }

  List<ConduceLegalidadFundamento> _mergeFundamentos(
    Iterable<ConduceLegalidadFundamento> fundamentos,
  ) {
    final result = <ConduceLegalidadFundamento>[];
    final seen = <String>{};

    for (final fundamento in fundamentos) {
      final key = _normalize(
        [
          fundamento.id.toString(),
          fundamento.codigo,
          fundamento.display,
          fundamento.referenciaLegalCorta,
        ].whereType<String>().join(' '),
      );
      if (seen.add(key)) {
        result.add(fundamento);
      }
    }

    return result;
  }

  static String _normalize(String value) {
    var text = value.toUpperCase().trim();
    text = text
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N');
    text = text.replaceAll(RegExp(r'[^A-Z0-9]+'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }
}
