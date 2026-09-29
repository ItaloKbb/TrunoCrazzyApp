import '../../../../core/error/app_exception.dart';
import '../../domain/enums/card_suit.dart';
import '../../domain/enums/card_value.dart';
import '../../domain/enums/game_direction.dart';
import '../../domain/enums/game_phase.dart';
import '../../domain/enums/round_status.dart';
import '../../domain/enums/skill_type.dart';

/// Converte o texto da API (ex.: `EM_ANDAMENTO`) em enum de dominio.
/// O dominio nao conhece esses textos: a traducao vive so na camada de dados.
T _parse<T>(Map<String, T> table, Object? raw, String what) {
  final value = table[raw];
  if (value == null) {
    throw UnexpectedException(
      message: 'Valor desconhecido recebido da API para $what: $raw',
    );
  }
  return value;
}

abstract final class EnumMappers {
  static const _phase = {
    'AGUARDANDO_JOGADORES': GamePhase.aguardandoJogadores,
    'EM_ANDAMENTO': GamePhase.emAndamento,
    'ENTRE_RODADAS': GamePhase.entreRodadas,
    'FINALIZADO': GamePhase.finalizado,
    'CANCELADO': GamePhase.cancelado,
  };
  static const _roundStatus = {
    'EM_ANDAMENTO': RoundStatus.emAndamento,
    'AGUARDANDO_PUZZLE': RoundStatus.aguardandoPuzzle,
    'FINALIZADO': RoundStatus.finalizado,
  };
  static const _direction = {
    'HORARIO': GameDirection.horario,
    'ANTI_HORARIO': GameDirection.antiHorario,
  };
  static const _value = {
    'AS': CardValue.as,
    'DOIS': CardValue.dois,
    'TRES': CardValue.tres,
    'QUATRO': CardValue.quatro,
    'CINCO': CardValue.cinco,
    'SEIS': CardValue.seis,
    'SETE': CardValue.sete,
    'DAMA': CardValue.dama,
    'VALETE': CardValue.valete,
    'REI': CardValue.rei,
  };
  static const _suit = {
    'OUROS': CardSuit.ouros,
    'ESPADAS': CardSuit.espadas,
    'COPAS': CardSuit.copas,
    'PAUS': CardSuit.paus,
  };
  static const _skill = {
    'BLOCK': SkillType.block,
    'THEFT': SkillType.theft,
    'INVERTS': SkillType.inverts,
    'BUY': SkillType.buy,
    'BURN': SkillType.burn,
    'SURPRISE': SkillType.surprise,
    'PUZZLE': SkillType.puzzle,
    'CHANGEOFHANDS': SkillType.changeOfHands,
    'BOMB': SkillType.bomb,
    'SHIELD': SkillType.shield,
  };

  static GamePhase phase(Object? raw) => _parse(_phase, raw, 'phase');
  static RoundStatus roundStatus(Object? raw) =>
      _parse(_roundStatus, raw, 'roundStatus');
  static GameDirection direction(Object? raw) =>
      _parse(_direction, raw, 'direction');
  static CardValue cardValue(Object? raw) => _parse(_value, raw, 'valor');
  static CardSuit cardSuit(Object? raw) => _parse(_suit, raw, 'naipe');
  static SkillType skillType(Object? raw) => _parse(_skill, raw, 'skill');

  static RoundStatus? roundStatusOrNull(Object? raw) =>
      raw == null ? null : roundStatus(raw);
  static SkillType? skillTypeOrNull(Object? raw) =>
      raw == null ? null : skillType(raw);
}
