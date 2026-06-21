class MarcaVehiculoOption {
  final String value;
  final List<String> tipos;

  const MarcaVehiculoOption(this.value, {required this.tipos});

  bool matches({required String? tipoGeneral}) {
    final tipo = (tipoGeneral ?? '').trim();
    if (tipo.isEmpty) {
      return true;
    }

    return tipos.contains(tipo);
  }
}

class MarcasVehiculo {
  static const String automovil = 'automovil';
  static const String camioneta = 'camioneta';
  static const String camion = 'camion';
  static const String motocicleta = 'motocicleta';
  static const String bicicleta = 'bicicleta';
  static const String remolque = 'remolque';
  static const String maquinaria = 'maquinaria';
  static const String tren = 'tren';
  static const String semoviente = 'semoviente';

  static const List<MarcaVehiculoOption> opciones = [
    MarcaVehiculoOption('ABARTH', tipos: [automovil]),
    MarcaVehiculoOption('ACURA', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('AJP', tipos: [motocicleta]),
    MarcaVehiculoOption('ALFA ROMEO', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('ALSTOM', tipos: [tren]),
    MarcaVehiculoOption('AION', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('ANKAI', tipos: [camion]),
    MarcaVehiculoOption('APRILIA', tipos: [motocicleta]),
    MarcaVehiculoOption('ARCFOX', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('AITO', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('ATRO', tipos: [remolque]),
    MarcaVehiculoOption('AUDI', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('AVATR', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('BAIC', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('BAJAJ', tipos: [motocicleta]),
    MarcaVehiculoOption('BENDA', tipos: [motocicleta]),
    MarcaVehiculoOption('BENTLEY', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('BENELLI', tipos: [motocicleta]),
    MarcaVehiculoOption('BETA', tipos: [motocicleta]),
    MarcaVehiculoOption('BENOTTO', tipos: [bicicleta]),
    MarcaVehiculoOption('BIANCHI', tipos: [bicicleta]),
    MarcaVehiculoOption('BIMOTA', tipos: [motocicleta]),
    MarcaVehiculoOption('BMW', tipos: [automovil, camioneta, motocicleta]),
    MarcaVehiculoOption('BOBCAT', tipos: [maquinaria]),
    MarcaVehiculoOption('BOMBARDIER', tipos: [tren]),
    MarcaVehiculoOption('BRILLIANCE', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('BUICK', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('BYD', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('CADILLAC', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('CAF', tipos: [tren]),
    MarcaVehiculoOption('CAN-AM', tipos: [motocicleta]),
    MarcaVehiculoOption('CANNONDALE', tipos: [bicicleta]),
    MarcaVehiculoOption('CARABELA', tipos: [motocicleta]),
    MarcaVehiculoOption('CASE', tipos: [maquinaria]),
    MarcaVehiculoOption('CATERPILLAR', tipos: [maquinaria]),
    MarcaVehiculoOption('CFMOTO', tipos: [motocicleta]),
    MarcaVehiculoOption('CHANGAN', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('CHERY', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('CHEVROLET', tipos: [automovil, camioneta, camion]),
    MarcaVehiculoOption('CHIREY', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('CHRYSLER', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('CIMC', tipos: [remolque]),
    MarcaVehiculoOption('CITROEN', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('CLARK', tipos: [maquinaria]),
    MarcaVehiculoOption('CLEVELAND CYCLEWERKS', tipos: [motocicleta]),
    MarcaVehiculoOption('CROWN', tipos: [maquinaria]),
    MarcaVehiculoOption('CRRC', tipos: [tren]),
    MarcaVehiculoOption('CUBE', tipos: [bicicleta]),
    MarcaVehiculoOption('CUPRA', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('DACIA', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('DAF', tipos: [camion]),
    MarcaVehiculoOption('DAIHATSU', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('DEEPAL', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('DENZA', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('DFSK', tipos: [automovil, camioneta, camion]),
    MarcaVehiculoOption('DINA', tipos: [camion]),
    MarcaVehiculoOption('DINAMO', tipos: [motocicleta]),
    MarcaVehiculoOption('DODGE', tipos: [automovil, camioneta, camion]),
    MarcaVehiculoOption('DONGFENG', tipos: [automovil, camioneta, camion]),
    MarcaVehiculoOption('DOOSAN', tipos: [maquinaria]),
    MarcaVehiculoOption('DS', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('DUCATI', tipos: [motocicleta]),
    MarcaVehiculoOption('EXEED', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('EXLANTIX', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('EMD', tipos: [tren]),
    MarcaVehiculoOption('FAW', tipos: [automovil, camioneta, camion]),
    MarcaVehiculoOption('FARIZON', tipos: [camioneta, camion]),
    MarcaVehiculoOption('FERRARI', tipos: [automovil]),
    MarcaVehiculoOption('FIAT', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('FONTAINE', tipos: [remolque]),
    MarcaVehiculoOption('FORD', tipos: [automovil, camioneta, camion]),
    MarcaVehiculoOption('FOTON', tipos: [camioneta, camion]),
    MarcaVehiculoOption('FREIGHTLINER', tipos: [camion]),
    MarcaVehiculoOption('FORTHING', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('FRUEHAUF', tipos: [remolque]),
    MarcaVehiculoOption('FUSO', tipos: [camion]),
    MarcaVehiculoOption('GASGAS', tipos: [motocicleta]),
    MarcaVehiculoOption('GAC', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('GE', tipos: [tren]),
    MarcaVehiculoOption('GEELY', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('GENESIS', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('GENIE', tipos: [maquinaria]),
    MarcaVehiculoOption('GIANT', tipos: [bicicleta]),
    MarcaVehiculoOption('GMC', tipos: [camioneta, camion]),
    MarcaVehiculoOption('GOLDEN DRAGON', tipos: [camion]),
    MarcaVehiculoOption('GREAT DANE', tipos: [remolque]),
    MarcaVehiculoOption('GREAT WALL', tipos: [camioneta]),
    MarcaVehiculoOption('GT', tipos: [bicicleta]),
    MarcaVehiculoOption('GWM', tipos: [automovil, camioneta, camion]),
    MarcaVehiculoOption('HARLEY-DAVIDSON', tipos: [motocicleta]),
    MarcaVehiculoOption('HAVAL', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('HERO', tipos: [motocicleta]),
    MarcaVehiculoOption('HINO', tipos: [camion]),
    MarcaVehiculoOption('HITACHI', tipos: [maquinaria]),
    MarcaVehiculoOption('HIGER', tipos: [camion]),
    MarcaVehiculoOption('HONDA', tipos: [automovil, camioneta, motocicleta]),
    MarcaVehiculoOption('HONGQI', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('HUFFY', tipos: [bicicleta]),
    MarcaVehiculoOption('HUMMER', tipos: [camioneta]),
    MarcaVehiculoOption('HUSQVARNA', tipos: [motocicleta]),
    MarcaVehiculoOption('HYSTER', tipos: [maquinaria]),
    MarcaVehiculoOption(
      'HYUNDAI',
      tipos: [automovil, camioneta, camion, maquinaria],
    ),
    MarcaVehiculoOption('HYUNDAI TRANSLEAD', tipos: [remolque]),
    MarcaVehiculoOption('INDIAN', tipos: [motocicleta]),
    MarcaVehiculoOption('INFINITI', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('INTERNATIONAL', tipos: [camion]),
    MarcaVehiculoOption('ISUZU', tipos: [camioneta, camion]),
    MarcaVehiculoOption('ITALIKA', tipos: [motocicleta]),
    MarcaVehiculoOption('IVECO', tipos: [camion]),
    MarcaVehiculoOption('IZUKA', tipos: [motocicleta]),
    MarcaVehiculoOption('ICAR', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('JAC', tipos: [automovil, camioneta, camion]),
    MarcaVehiculoOption('JAECOO', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('JAGUAR', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('JCB', tipos: [maquinaria]),
    MarcaVehiculoOption('JEEP', tipos: [automovil]),
    MarcaVehiculoOption('JETOUR', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('JMC', tipos: [camioneta, camion]),
    MarcaVehiculoOption('JLG', tipos: [maquinaria]),
    MarcaVehiculoOption('JOHN DEERE', tipos: [maquinaria]),
    MarcaVehiculoOption('KANSAS CITY SOUTHERN', tipos: [tren]),
    MarcaVehiculoOption('KAWASAKI', tipos: [motocicleta]),
    MarcaVehiculoOption('KAIYI', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('KARRY', tipos: [automovil, camioneta, camion]),
    MarcaVehiculoOption('KEEWAY', tipos: [motocicleta]),
    MarcaVehiculoOption('KENWORTH', tipos: [camion]),
    MarcaVehiculoOption('KIA', tipos: [automovil, camioneta, camion]),
    MarcaVehiculoOption('KOMATSU', tipos: [maquinaria]),
    MarcaVehiculoOption('KTM', tipos: [motocicleta]),
    MarcaVehiculoOption('KOVE', tipos: [motocicleta]),
    MarcaVehiculoOption('KUBOTA', tipos: [maquinaria]),
    MarcaVehiculoOption('KURAZAI', tipos: [motocicleta]),
    MarcaVehiculoOption('KYMCO', tipos: [motocicleta]),
    MarcaVehiculoOption('LAMBORGHINI', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('LAND ROVER', tipos: [camioneta]),
    MarcaVehiculoOption('LEAPMOTOR', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('LEPAS', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('LEXUS', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('LIEBHERR', tipos: [maquinaria]),
    MarcaVehiculoOption('LIFAN', tipos: [motocicleta]),
    MarcaVehiculoOption('LINCOLN', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('LIUGONG', tipos: [maquinaria]),
    MarcaVehiculoOption('LONCIN', tipos: [motocicleta]),
    MarcaVehiculoOption('LOZANO', tipos: [remolque]),
    MarcaVehiculoOption('LUFKIN', tipos: [remolque]),
    MarcaVehiculoOption('LUXEED', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('LYNK & CO', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('MACK', tipos: [camion]),
    MarcaVehiculoOption('MAN', tipos: [camion]),
    MarcaVehiculoOption('MANITOU', tipos: [maquinaria]),
    MarcaVehiculoOption('MASERATI', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('MAZDA', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('MAXUS', tipos: [automovil, camioneta, camion]),
    MarcaVehiculoOption('MB MOTORS', tipos: [motocicleta]),
    MarcaVehiculoOption('MERCEDES-BENZ', tipos: [automovil, camioneta, camion]),
    MarcaVehiculoOption('MERIDA', tipos: [bicicleta]),
    MarcaVehiculoOption('MG', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('MINI', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('MOBILITY ADO', tipos: [camion]),
    MarcaVehiculoOption('MITSUBISHI', tipos: [automovil, camioneta, camion]),
    MarcaVehiculoOption('MONGOOSE', tipos: [bicicleta]),
    MarcaVehiculoOption('MOTO GUZZI', tipos: [motocicleta]),
    MarcaVehiculoOption('MOTO MORINI', tipos: [motocicleta]),
    MarcaVehiculoOption('MV AGUSTA', tipos: [motocicleta]),
    MarcaVehiculoOption('NAVISTAR', tipos: [camion]),
    MarcaVehiculoOption('NETA', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('NEW HOLLAND', tipos: [maquinaria]),
    MarcaVehiculoOption('NIO', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('NISSAN', tipos: [automovil, camioneta, camion]),
    MarcaVehiculoOption('NO APLICA', tipos: [semoviente]),
    MarcaVehiculoOption('OMODA', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('ORA', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('OPEL', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('ORBEA', tipos: [bicicleta]),
    MarcaVehiculoOption('PETERBILT', tipos: [camion]),
    MarcaVehiculoOption('PEUGEOT', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('PIAGGIO', tipos: [motocicleta]),
    MarcaVehiculoOption('PLYMOUTH', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('POLARIS', tipos: [motocicleta]),
    MarcaVehiculoOption('POLESTAR', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('PONTIAC', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('PORSCHE', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('QJMOTOR', tipos: [motocicleta]),
    MarcaVehiculoOption('RALEIGH', tipos: [bicicleta]),
    MarcaVehiculoOption('RADAR', tipos: [camioneta]),
    MarcaVehiculoOption('RAM', tipos: [camioneta, camion]),
    MarcaVehiculoOption('REA', tipos: [remolque]),
    MarcaVehiculoOption('RENAULT', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('RIVIAN', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('ROYAL ENFIELD', tipos: [motocicleta]),
    MarcaVehiculoOption('SAAB', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('SANY', tipos: [maquinaria]),
    MarcaVehiculoOption('SCANIA', tipos: [camion]),
    MarcaVehiculoOption('SCOTT', tipos: [bicicleta]),
    MarcaVehiculoOption('SDLG', tipos: [maquinaria]),
    MarcaVehiculoOption('SERES', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('SEAT', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('SHACMAN', tipos: [camion]),
    MarcaVehiculoOption('SHINERAY', tipos: [motocicleta]),
    MarcaVehiculoOption('SIEMENS', tipos: [tren]),
    MarcaVehiculoOption('SINOTRUK', tipos: [camion]),
    MarcaVehiculoOption('SITRAK', tipos: [camion]),
    MarcaVehiculoOption('SKODA', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('SKYJACK', tipos: [maquinaria]),
    MarcaVehiculoOption('SKYWORTH', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('SMART', tipos: [automovil]),
    MarcaVehiculoOption('SPECIALIZED', tipos: [bicicleta]),
    MarcaVehiculoOption('STERLING', tipos: [camion]),
    MarcaVehiculoOption('STOUGHTON', tipos: [remolque]),
    MarcaVehiculoOption('SUBARU', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('SUNLONG', tipos: [camion]),
    MarcaVehiculoOption('SUZUKI', tipos: [automovil, camioneta, motocicleta]),
    MarcaVehiculoOption('SWM', tipos: [automovil, camioneta, motocicleta]),
    MarcaVehiculoOption('SYM', tipos: [motocicleta]),
    MarcaVehiculoOption('TANK', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('TEREX', tipos: [maquinaria]),
    MarcaVehiculoOption('TESLA', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('TOYOTA', tipos: [automovil, camioneta, maquinaria]),
    MarcaVehiculoOption('TRAILMOBILE', tipos: [remolque]),
    MarcaVehiculoOption('TREK', tipos: [bicicleta]),
    MarcaVehiculoOption('TREMAC', tipos: [remolque]),
    MarcaVehiculoOption('TRIUMPH', tipos: [motocicleta]),
    MarcaVehiculoOption('TVS', tipos: [motocicleta]),
    MarcaVehiculoOption('UD TRUCKS', tipos: [camion]),
    MarcaVehiculoOption('UTILITY', tipos: [remolque]),
    MarcaVehiculoOption('VENTO', tipos: [motocicleta]),
    MarcaVehiculoOption('VESPA', tipos: [motocicleta]),
    MarcaVehiculoOption('VELOCI', tipos: [motocicleta]),
    MarcaVehiculoOption('VICTORY', tipos: [motocicleta]),
    MarcaVehiculoOption('VINFAST', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('VOGE', tipos: [motocicleta]),
    MarcaVehiculoOption('VOLKSWAGEN', tipos: [automovil, camioneta]),
    MarcaVehiculoOption(
      'VOLVO',
      tipos: [automovil, camioneta, camion, maquinaria],
    ),
    MarcaVehiculoOption('WABASH', tipos: [remolque]),
    MarcaVehiculoOption('WABTEC', tipos: [tren]),
    MarcaVehiculoOption('WEY', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('WULING', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('WESTERN STAR', tipos: [camion]),
    MarcaVehiculoOption('WILSON', tipos: [remolque]),
    MarcaVehiculoOption('XCMG', tipos: [maquinaria]),
    MarcaVehiculoOption('XPENG', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('YANGWANG', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('YALE', tipos: [maquinaria]),
    MarcaVehiculoOption('YAMAHA', tipos: [motocicleta]),
    MarcaVehiculoOption('YUTONG', tipos: [camion]),
    MarcaVehiculoOption('ZANELLA', tipos: [motocicleta]),
    MarcaVehiculoOption('ZEEKR', tipos: [automovil, camioneta]),
    MarcaVehiculoOption('ZHONGTONG', tipos: [camion]),
    MarcaVehiculoOption('ZONTES', tipos: [motocicleta]),
  ];

  static const Map<String, String> aliases = {
    'BAIC MOTOR': 'BAIC',
    'BAJAJ AUTO': 'BAJAJ',
    'BEIJING AUTOMOTIVE': 'BAIC',
    'BEIJING': 'BAIC',
    'BUILD YOUR DREAMS': 'BYD',
    'BYD AUTO': 'BYD',
    'CHANG AN': 'CHANGAN',
    'CHERY AUTOMOBILE': 'CHERY',
    'CHIREY MOTOR': 'CHIREY',
    'CF MOTO': 'CFMOTO',
    'CF-MOTO': 'CFMOTO',
    'CHINA FAW': 'FAW',
    'DFM': 'DONGFENG',
    'DONG FENG': 'DONGFENG',
    'DONGFENG MOTOR': 'DONGFENG',
    'DONGFENG FORTHING': 'FORTHING',
    'EXEED MOTORS': 'EXEED',
    'FANGCHENGBAO': 'BYD',
    'FANG CHENG BAO': 'BYD',
    'GEELY RADAR': 'RADAR',
    'GEELY FARIZON': 'FARIZON',
    'GREAT WALL': 'GWM',
    'GREAT WALL MOTOR': 'GWM',
    'GREAT WALL MOTORS': 'GWM',
    'GWM ORA': 'ORA',
    'GWM TANK': 'TANK',
    'GWM HAVAL': 'HAVAL',
    'GWM WEY': 'WEY',
    'GM': 'CHEVROLET',
    'GENERAL MOTORS': 'CHEVROLET',
    'GENERAL MOTORS DE MEXICO': 'CHEVROLET',
    'GUANGZHOU AUTOMOBILE': 'GAC',
    'GAC MOTOR': 'GAC',
    'GAC AION': 'AION',
    'HERO MOTOCORP': 'HERO',
    'HONDA MOTOR': 'HONDA',
    'HONDA DE MEXICO': 'HONDA',
    'HONDA MEXICO': 'HONDA',
    'HYUNDAI MOTOR': 'HYUNDAI',
    'JAC MOTORS': 'JAC',
    'JAC MOTOR': 'JAC',
    'JAECOO MEXICO': 'JAECOO',
    'JETOUR AUTO': 'JETOUR',
    'KARRY AUTO': 'KARRY',
    'JMC MOTORS': 'JMC',
    'KIA MOTORS': 'KIA',
    'MERCEDEZ BENZ': 'MERCEDES-BENZ',
    'MERCEDES BENZ': 'MERCEDES-BENZ',
    'MERCEDES BENZ MEXICO': 'MERCEDES-BENZ',
    'MERCEDES-BENZ MEXICO': 'MERCEDES-BENZ',
    'MG MOTOR': 'MG',
    'MORRIS GARAGES': 'MG',
    'NISSAN MEXICANA': 'NISSAN',
    'NISSAN MEXICO': 'NISSAN',
    'OMODA JAECOO': 'OMODA',
    'QJ MOTOR': 'QJMOTOR',
    'QJ-MOTOR': 'QJMOTOR',
    'LYNK AND CO': 'LYNK & CO',
    'LYNK CO': 'LYNK & CO',
    'SAIC MAXUS': 'MAXUS',
    'SAIC MOTOR': 'MG',
    'SERES GROUP': 'SERES',
    'SOKON': 'DFSK',
    'SWM MOTORS': 'SWM',
    'TOYOTA MOTOR': 'TOYOTA',
    'TVS MOTOR': 'TVS',
    'VELOCI MOTORS': 'VELOCI',
    'VELOCI MOTOR': 'VELOCI',
    'VOLVO TRUCKS': 'VOLVO',
    'VOLVO CAR': 'VOLVO',
    'XPENG MOTORS': 'XPENG',
    'XPENG AUTO': 'XPENG',
    'VW': 'VOLKSWAGEN',
    'V W': 'VOLKSWAGEN',
    'VOLKS WAGEN': 'VOLKSWAGEN',
    'VOLKSWAGEN DE MEXICO': 'VOLKSWAGEN',
    'HARLEY DAVIDSON': 'HARLEY-DAVIDSON',
    'LANDROVER': 'LAND ROVER',
    'K C S M': 'KANSAS CITY SOUTHERN',
    'KCSM': 'KANSAS CITY SOUTHERN',
  };

  static List<String> opcionesPara({
    required String? tipoGeneral,
    required String? carroceria,
  }) {
    if ((tipoGeneral ?? '').trim().isEmpty ||
        (carroceria ?? '').trim().isEmpty) {
      return const [];
    }

    final items = <String>[];
    for (final option in opciones) {
      if (!option.matches(tipoGeneral: tipoGeneral)) {
        continue;
      }
      if (!items.contains(option.value)) {
        items.add(option.value);
      }
    }

    return items;
  }

  static String? valueFromAny(
    String? raw, {
    String? tipoGeneral,
    String? carroceria,
  }) {
    if ((tipoGeneral ?? '').trim().isEmpty ||
        (carroceria ?? '').trim().isEmpty) {
      return null;
    }

    final value = normalize(raw);
    if (value == null) {
      return null;
    }

    final option = _optionByValue(value);
    if (option == null) {
      return null;
    }

    if (!option.matches(tipoGeneral: tipoGeneral)) {
      return null;
    }

    return value;
  }

  static String? normalize(String? raw) {
    final key = _normalizeKey(raw);
    if (key.isEmpty) {
      return null;
    }

    final alias = aliases[key];
    if (alias != null) {
      return alias;
    }

    final sorted = List<MarcaVehiculoOption>.from(opciones)
      ..sort(
        (a, b) => _normalizeKey(
          b.value,
        ).length.compareTo(_normalizeKey(a.value).length),
      );

    for (final option in sorted) {
      final optionKey = _normalizeKey(option.value);
      if (_hasToken(key, optionKey)) {
        return option.value;
      }
    }

    return null;
  }

  static String? validateSelection(
    String? raw, {
    required String? tipoGeneral,
    required String? carroceria,
  }) {
    if ((tipoGeneral ?? '').trim().isEmpty ||
        (carroceria ?? '').trim().isEmpty) {
      return null;
    }

    if ((raw ?? '').trim().isEmpty) {
      return 'Requerido';
    }

    if (valueFromAny(raw, tipoGeneral: tipoGeneral, carroceria: carroceria) ==
        null) {
      return 'Selecciona una marca válida para ese tipo de vehículo.';
    }

    return null;
  }

  static MarcaVehiculoOption? _optionByValue(String value) {
    for (final option in opciones) {
      if (option.value == value) {
        return option;
      }
    }
    return null;
  }

  static bool _hasToken(String haystack, String needle) {
    if (haystack == needle) {
      return true;
    }

    final escaped = RegExp.escape(needle);
    return RegExp('(^| )$escaped( |\$)').hasMatch(haystack);
  }

  static String _normalizeKey(String? raw) {
    var value = (raw ?? '').trim().toUpperCase();
    if (value.isEmpty) {
      return '';
    }

    const replacements = {
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'Ü': 'U',
      'Ñ': 'N',
    };

    replacements.forEach((from, to) {
      value = value.replaceAll(from, to);
    });

    value = value
        .replaceAll('&', ' ')
        .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
        .replaceAll(RegExp(r'\b(SA|S A|DE|CV|C V|RL|R L|SAPI|S A P I)\b'), ' ')
        .replaceAll(
          RegExp(r'\b(MEXICO|MEXICANA|MEXICANO|COMPANY|COMPANIA)\b'),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return value;
  }
}
