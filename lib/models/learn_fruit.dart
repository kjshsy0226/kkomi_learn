import 'package:flutter/foundation.dart';

/// 노랑(세트2) + 초록(세트3) 20개
enum LearnFruit {
  // 세트2
  apple,
  napaCabbage,
  onion,
  cucumber,
  tangerine,
  spinach,
  orientalMelon,
  carrot,
  banana,
  peach,
  // 세트3
  eggplant,
  paprika,
  watermelon,
  tomato,
  pumpkin,
  kiwi,
  grape,
  pineapple,
  strawberry,
  radish,
}

@immutable
class LearnFruitMeta {
  final String key; // 파일/폴더명 (snake_case)
  final String titleKo; // UI 표기
  const LearnFruitMeta(this.key, this.titleKo);
}

const Map<LearnFruit, LearnFruitMeta> kLearnFruitMeta = {
  // 세트2
  LearnFruit.apple: LearnFruitMeta('apple', '사과'),
  LearnFruit.napaCabbage: LearnFruitMeta('napa_cabbage', '배추'),
  LearnFruit.onion: LearnFruitMeta('onion', '양파'),
  LearnFruit.cucumber: LearnFruitMeta('cucumber', '오이'),
  LearnFruit.tangerine: LearnFruitMeta('tangerine', '귤'),
  LearnFruit.spinach: LearnFruitMeta('spinach', '시금치'),
  LearnFruit.orientalMelon: LearnFruitMeta('oriental_melon', '참외'),
  LearnFruit.carrot: LearnFruitMeta('carrot', '당근'),
  LearnFruit.banana: LearnFruitMeta('banana', '바나나'),
  LearnFruit.peach: LearnFruitMeta('peach', '복숭아'),
  // 세트3
  LearnFruit.eggplant: LearnFruitMeta('eggplant', '가지'),
  LearnFruit.paprika: LearnFruitMeta('paprika', '파프리카'),
  LearnFruit.watermelon: LearnFruitMeta('watermelon', '수박'),
  LearnFruit.tomato: LearnFruitMeta('tomato', '토마토'),
  LearnFruit.pumpkin: LearnFruitMeta('pumpkin', '호박'),
  LearnFruit.kiwi: LearnFruitMeta('kiwi', '키위'),
  LearnFruit.grape: LearnFruitMeta('grape', '포도'),
  LearnFruit.pineapple: LearnFruitMeta('pineapple', '파인애플'),
  LearnFruit.strawberry: LearnFruitMeta('strawberry', '딸기'),
  LearnFruit.radish: LearnFruitMeta('radish', '무'),
};

String learnbackgroundPath(LearnFruit f) =>
    'assets/images/fruits/learn/${kLearnFruitMeta[f]!.key}/bg.jpg';
String learnTrayPath(LearnFruit f) =>
    'assets/images/fruits/learn/${kLearnFruitMeta[f]!.key}/tray.png';
String learnNormalPath(LearnFruit f) =>
    'assets/images/fruits/learn/${kLearnFruitMeta[f]!.key}/whole.png';
String learnHalfPath(LearnFruit f) =>
    'assets/images/fruits/learn/${kLearnFruitMeta[f]!.key}/slice.png';

String learnCuriousVideo(LearnFruit f) =>
    'assets/videos/reactions/learn/${kLearnFruitMeta[f]!.key}_curious.mp4';
String learnLikeVideo(LearnFruit f) =>
    'assets/videos/reactions/learn/${kLearnFruitMeta[f]!.key}_like.mp4';

const List<LearnFruit> kGameSet2 = [
  LearnFruit.apple,
  LearnFruit.napaCabbage,
  LearnFruit.onion,
  LearnFruit.cucumber,
  LearnFruit.tangerine,
  LearnFruit.spinach,
  LearnFruit.orientalMelon,
  LearnFruit.carrot,
  LearnFruit.banana,
  LearnFruit.peach,
];

const List<LearnFruit> kGameSet3 = [
  LearnFruit.eggplant,
  LearnFruit.paprika,
  LearnFruit.watermelon,
  LearnFruit.tomato,
  LearnFruit.pumpkin,
  LearnFruit.kiwi,
  LearnFruit.grape,
  LearnFruit.pineapple,
  LearnFruit.strawberry,
  LearnFruit.radish,
];
