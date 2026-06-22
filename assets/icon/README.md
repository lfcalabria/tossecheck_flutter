# Ícone do app

Coloque aqui a logo do TosseCheck com o nome exato:

```
assets/icon/tossecheck.png
```

Requisitos:
- Formato **PNG**, **quadrado** (ideal **1024×1024**).
- Para o ícone ficar legível em tamanhos pequenos, prefira **apenas o símbolo**
  (cabeça de cão/gato + onda + check), sem o texto "TosseCheck".

Depois de salvar o arquivo, gere os ícones de todas as plataformas com:

```bash
dart run flutter_launcher_icons
```

A configuração fica no `pubspec.yaml`, no bloco `flutter_launcher_icons:`.
```
