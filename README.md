# TosseCheck 🐾

Aplicativo Flutter para **tutores de pets** gravarem vídeos de episódios de tosse do animal e
recebê-los de volta com **observações de um veterinário**. O app funciona **offline-first**:
tudo é gravado primeiro no dispositivo (SQLite) e sincronizado com o backend assim que há
internet.

> `pubspec.yaml`: _"Aplicativo TosseCheck — Gravação e classificação de tosses de pets."_

---

## Índice

1. [Visão geral](#visão-geral)
2. [Stack e dependências](#stack-e-dependências)
3. [Arquitetura](#arquitetura)
4. [Modelo de dados](#modelo-de-dados)
5. [Comunicação com a API](#comunicação-com-a-api)
6. [Sincronização offline-first](#sincronização-offline-first)
7. [Controle de acesso (CPF)](#controle-de-acesso-cpf)
8. [Fluxo de telas](#fluxo-de-telas)
9. [Design / UX](#design--ux)
10. [Configuração](#configuração)
11. [Como rodar / build](#como-rodar--build)
12. [Estrutura de pastas](#estrutura-de-pastas)
13. [Troubleshooting](#troubleshooting)

---

## Visão geral

O TosseCheck conecta **tutor → vídeo da tosse → veterinário → observação**. O ciclo é:

1. O tutor se cadastra (nome, CPF, telefone).
2. Cadastra seus pets.
3. Grava um vídeo da tosse do pet (a câmera **inicia a gravação automaticamente**).
4. O vídeo é salvo localmente e enviado ao backend quando houver conexão.
5. Um veterinário (no sistema web/backend) analisa e registra **observações** (prontuário).
6. O app **baixa** de volta os pets, vídeos e observações e mostra para o tutor.

A premissa central é **resiliência sem rede**: gravar a tosse nunca pode falhar por falta de
internet. Por isso o SQLite local é a fonte de trabalho e o backend é um destino de
sincronização eventual.

---

## Stack e dependências

| Camada | Tecnologia |
|---|---|
| Framework | **Flutter** (Dart SDK `>=3.0.0 <4.0.0`) |
| UI | Material Design (`primarySwatch: teal`) |
| Banco local | **SQLite** via `sqflite` (e `sqflite_common_ffi` em desktop) |
| HTTP | `http` |
| Câmera | `camera` |
| Mídia | `video_player`, `image_picker` |
| Rede/estado | `connectivity_plus` |
| Arquivos | `path_provider`, `path` |
| IDs | `uuid` |
| Permissões | `permission_handler` |

Plataformas-alvo: Android (principal), além de iOS/Web/Desktop presentes no projeto. Em
desktop, o `main()` inicializa o `sqflite_common_ffi` para o banco funcionar fora de mobile.

---

## Arquitetura

Arquitetura em camadas simples, sem framework de estado pesado (usa `setState` + um callback
global de sincronização):

```
┌─────────────────────────────────────────────────────────┐
│                         UI (screens/)                     │
│  Boot · Cadastro · Lista · Gravar · Reproduzir · Detalhes │
└───────────────┬───────────────────────────┬──────────────┘
                │                            │
                ▼                            ▼
┌───────────────────────────┐   ┌──────────────────────────┐
│   DatabaseHelper           │   │   ApiService (singleton)  │
│   (SQLite — fonte local)   │◄──┤   sync + HTTP + conexão   │
└───────────────┬───────────┘   └──────────────┬───────────┘
                │                               │
                ▼                               ▼
┌───────────────────────────┐   ┌──────────────────────────┐
│   models/                  │   │   Backend REST            │
│   Usuario·Pet·Video·Obs    │   │   api.tecnologias...      │
└───────────────────────────┘   └──────────────────────────┘
```

Princípios:

- **`ApiService` é um singleton** (`ApiService()` sempre retorna a mesma instância). Centraliza
  todo HTTP, a checagem de conexão e a lógica de sync.
- **`DatabaseHelper` é um singleton** (`DatabaseHelper.instance`) que abre/migra o banco
  `tossecheck.db` (versão de schema **4**, com `onUpgrade` incremental).
- **Models são POJOs** com `toMap()` / `fromMap()` para serializar de/para o SQLite.
- A UI nunca fala HTTP direto: sempre passa por `ApiService` ou `DatabaseHelper`.
- Atualização reativa simples: a tela de lista registra `ApiService().onSyncComplete = ...`,
  e o serviço dispara esse callback quando a sincronização muda dados.

---

## Modelo de dados

Quatro entidades, persistidas em quatro tabelas SQLite. Cada registro tem um `uuid` (id
canônico do backend) **e** um `id` autoincrement local, além de timestamps e o flag
`sincronizado`.

```
Usuario (1) ──< Pet (N) ──< VideoPet (N)
                    └──────< Observacao (N)
```

| Entidade | Tabela | Campos-chave | Relacionamento |
|---|---|---|---|
| **Usuario** | `usuarios` | `uuid`, `cpf`, `nome`, `telefone`, `bloqueado`, `liberado` | 1 por dispositivo (`getUsuario()` lê `limit 1`) |
| **Pet** | `pets` | `uuid`, `usuario_uuid`, `nome`, `tipo`, `sexo`, `raca`, `idade`, `peso`, `altura`, `foto_path` | pertence a um usuário |
| **VideoPet** | `videos` | `uuid`, `pet_id`, `pet_uuid`, `caminho_local`, `url_servidor` | pertence a um pet |
| **Observacao** | `observacoes` | `uuid`, `pet_uuid`, `veterinario`, `mensagem` | pertence a um pet (vem do backend) |

Detalhes importantes:

- **Dupla referência do pet no vídeo** (`pet_id` local + `pet_uuid` do backend): permite gravar
  um vídeo mesmo antes de o pet ter sido sincronizado. Na hora do upload, o serviço resolve o
  `pet_uuid` a partir do `pet_id` se necessário.
- **`foto_path` é sempre local**: ao baixar pets do backend, a foto local é preservada (não é
  sobrescrita pelo download).
- **Observações são somente-leitura no app**: são geradas pelo veterinário no backend e o app
  apenas as baixa (campo `prontuario` da API). Por isso nascem com `sincronizado = 1`.

---

## Comunicação com a API

**Base URL** (definida em [`lib/services/api_service.dart`](lib/services/api_service.dart)):

```dart
static const String hostUrl = 'https://api.tecnologiasinternet.com.br';
static const String baseUrl = '$hostUrl/api/v1';
```

> `baseUrl` é derivado de `hostUrl` de propósito — para trocar o servidor basta editar **uma**
> linha.

### Endpoints usados

| Método | Endpoint | Uso |
|---|---|---|
| `GET`  | `/api/v1/tutor/usuario/?cpf={cpf}` | Consulta status do usuário por CPF (desbloqueio/validação) |
| `POST` | `/api/v1/tutor/sync/usuario/` | Cadastra/sincroniza o usuário (`nome`, `cpf`, `telefone`) |
| `GET`  | `/api/v1/tutor/pets/?usuario_uuid={uuid}` | Lista pets do usuário → `{ "pets": [...] }` |
| `GET`  | `/api/v1/pets/{petUuid}/` | Detalhe do pet → `{ "prontuario": [...], "videos": [...] }` |
| `POST` | `/api/v1/tutor/sync/pet/` | Envia um pet pendente |
| `POST` | `/api/v1/upload/video/` | Upload do arquivo de vídeo (`multipart`: campo `file` + `pet_uuid`) |

### Códigos de resposta tratados (sync de usuário)

| Status | Significado | Ação no app |
|---|---|---|
| `200/201` | Sucesso | Marca usuário como `liberado` e `sincronizado`, salva `uuid` |
| `409` | Conflito de CPF | Reconsulta status; se não liberar, **bloqueia e fecha o app** |
| `400` | Dados inválidos | Mostra mensagem de erro |
| outro | Erro genérico | Mostra mensagem de erro |

Todo parse de corpo passa por `_decodeBodySafe()`, que nunca lança exceção (retorna `{}` em
falha), evitando crashes por JSON inesperado.

---

## Sincronização offline-first

O coração do app. A regra é: **grave local primeiro, sincronize depois**.

- Cada registro tem `sincronizado` (`0` = pendente, `1` = no backend).
- `getPendentes(tabela)` retorna tudo com `sincronizado = 0`.
- O método `sincronizarGeral()` faz o ciclo completo, protegido contra reentrância
  (`_isSyncing`) e contra falta de rede (`hasInternet()`):

```
sincronizarGeral():
  1. Garante usuário desbloqueado e sincronizado
  2. Sobe PETS pendentes      → POST /tutor/sync/pet/
  3. Sobe VÍDEOS pendentes    → POST /upload/video/  (multipart)
  4. baixarTudoDoBackend():
       • GET /tutor/pets/?usuario_uuid=...      (upsert pets)
       • para cada pet: GET /pets/{uuid}/
            ├─ prontuario → upsert observações
            └─ videos     → baixa .mp4 p/ pasta local
  5. Dispara onSyncComplete() se algo mudou
```

**Quando a sincronização é disparada:**

| Gatilho | Onde |
|---|---|
| Reconexão de internet (Wi-Fi/dados) | `iniciarListenerDeConexao()` no `main()` |
| Abertura do app | `BootScreen._boot()` |
| Após cadastro do usuário | `CadastroUsuarioScreen` |
| Após salvar edição de pet | `EditarPetScreen._salvar()` |
| Após vincular um vídeo a um pet | `SelecionarPetVideoScreen` |
| Botão de sync manual (ícone 🔄) | `ListaPetsScreen` |

Os vídeos baixados ficam em `…/Documents/videos/{uuid}.mp4` e não são rebaixados se já
existirem localmente.

---

## Controle de acesso (CPF)

O acesso é controlado pelo backend a partir do **CPF**, com dois flags por usuário:
`bloqueado` e `liberado`.

- No cadastro, o usuário é criado localmente como `liberado = false` (pendente de validação).
- Se **online**, faz `POST /tutor/sync/usuario/`:
  - sucesso → `liberado = true`;
  - `409` (CPF já existe com dados divergentes) → o app marca como **bloqueado** e **encerra**
    (`SystemNavigator.pop()`), mostrando *"Acesso bloqueado"*.
- Se **offline**, o app deixa entrar mesmo assim — a validação acontece na próxima vez online.
- Na inicialização (`BootScreen`), se o usuário estiver `bloqueado`, o app tenta **desbloquear**
  consultando o backend (`tentarDesbloquearSePossivel`); se não conseguir, exibe o diálogo de
  bloqueio e fecha.

O CPF também é validado **localmente** antes de qualquer chamada, via
[`lib/utils/cpf_validator.dart`](lib/utils/cpf_validator.dart) (`isValidCPF`).

---

## Fluxo de telas

```
main()
  └─ BootScreen ── usuário existe? ──► sim ─► ListaPetsScreen
                       │
                       └─ não ─► CadastroUsuarioScreen ─► ListaPetsScreen

ListaPetsScreen
  ├─ [+]            ─► CadastroPetScreen
  ├─ [🔄]           ─► força sincronização
  ├─ toque no pet  ─► GravarTosseAutoScreen (grava p/ este pet)
  ├─ [☁️]  por pet ─► lista de VÍDEOS ─► ReproduzirVideoScreen
  ├─ [🩺] por pet  ─► lista de OBSERVAÇÕES ─► DetalhesObservacaoScreen
  ├─ [✏️]  por pet ─► EditarPetScreen
  └─ FAB "GRAVAR TOSSE" ─► GravarTosseAutoScreen (sem pet)
                              └─► SelecionarPetVideoScreen ("Quem tossiu?")
```

Telas (em [`lib/screens/`](lib/screens/)):

| Tela | Papel |
|---|---|
| `boot_screen.dart` | Decide rota inicial; trata bloqueio e sync de abertura |
| `cadastro_usuario_screen.dart` | Cadastro do tutor (nome/CPF/telefone) com validação |
| `lista_pets_screen.dart` | Hub principal: lista de pets + ações (vídeos, observações, editar, gravar) |
| `cadastro_pet_screen.dart` | Cadastro de um novo pet |
| `editar_pet_screen.dart` | Edição do pet + foto + ver vídeos/observações |
| `gravar_tosse_auto_screen.dart` | Câmera com **gravação automática** ao abrir |
| `selecionar_pet_video_screen.dart` | Vincula um vídeo recém-gravado ao pet correto |
| `reproduzir_video_screen.dart` | Reproduz um vídeo |
| `detalhes_observacao_screen.dart` | Lê a observação do veterinário |

Na lista de pets, cada item tem, à direita, **três ícones**:

| Ícone | Cor | Ação |
|---|---|---|
| ☁️ `cloud_done` / `cloud_upload` | verde = sincronizado · laranja = pendente | Ver **vídeos** gravados do pet |
| 🩺 `medical_information` | teal | Ver **observações** do veterinário |
| ✏️ `edit` | — | **Editar** o pet |

> O ícone de nuvem também comunica o **status de sincronização** do pet pela cor, além de abrir
> os vídeos ao toque.

---

## Design / UX

- **Tema**: Material, `primarySwatch: Colors.teal`; banner de debug desativado.
- **Identidade**: ícone de patinha (`Icons.pets`), tons de teal, ação de gravar em vermelho
  (destaque de urgência).
- **Gravação sem fricção**: ao abrir a câmera, a gravação **começa sozinha** — o tutor só
  precisa apontar e tocar em parar. A ideia é capturar a tosse, que é rápida e imprevisível.
- **Feedback**: `SnackBar` para sucesso/erro; `CircularProgressIndicator` durante operações;
  diálogos modais para bloqueio de acesso.
- **Listas em bottom sheet**: vídeos e observações abrem em `showModalBottomSheet`, mantendo o
  contexto da lista de pets.

---

## Configuração

### URL da API

Edite em [`lib/services/api_service.dart`](lib/services/api_service.dart) (apenas o `hostUrl`):

```dart
static const String hostUrl = 'https://api.tecnologiasinternet.com.br';
static const String baseUrl = '$hostUrl/api/v1';
```

Valores comuns conforme o alvo:

| Ambiente | `hostUrl` |
|---|---|
| Produção | `https://api.tecnologiasinternet.com.br` |
| Emulador Android + backend local | `http://10.0.2.2:8000` |
| Celular real + backend na mesma Wi-Fi | `http://192.168.x.x:8000` (use `ipconfig`) |

> **`10.0.2.2`** é um apelido **exclusivo do emulador Android** para o `localhost` da máquina —
> **não** funciona em celular físico.

### Android — rede

Em [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml):

- **`<uses-permission android:name="android.permission.INTERNET"/>`** — obrigatório no manifest
  **principal** para o APK de **release** ter acesso à rede. (O manifest de `debug` já inclui
  essa permissão automaticamente, por isso o app funciona em debug mesmo sem ela no `main`.)
- **`android:usesCleartextTraffic="true"`** — necessário enquanto a API for `http://` (sem TLS).
  Com a API em `https://`, o cleartext deixa de ser necessário.

---

## Como rodar / build

Pré-requisitos: Flutter SDK instalado e um device/emulador disponível.

```bash
# Instalar dependências
flutter pub get

# Rodar em modo debug
flutter run

# Gerar APK de release
flutter build apk
# saída: build/app/outputs/flutter-apk/app-release.apk
```

> **Tamanho do APK**: um build **release** (~55 MB) é naturalmente bem menor que um **debug**
> (~160 MB+). O release usa compilação AOT, *tree-shaking* de ícones e remoção de símbolos de
> debug. APK release menor é o comportamento **esperado**, não um defeito.

---

## Estrutura de pastas

```
lib/
├── main.dart                       # Bootstrap: SQLite (FFI desktop), listener de conexão, MaterialApp
├── database/
│   └── database_helper.dart        # Singleton SQLite: schema, migrações, CRUD, pendentes
├── models/
│   ├── usuario.dart                # Tutor (CPF, flags bloqueado/liberado)
│   ├── pet.dart                    # Pet do tutor
│   ├── videopet.dart               # Vídeo de tosse (pet_id local + pet_uuid backend)
│   └── observacao.dart             # Observação do veterinário (prontuário)
├── services/
│   └── api_service.dart            # Singleton: HTTP, conexão e toda a sincronização
├── screens/                        # Telas (ver tabela acima)
└── utils/
    └── cpf_validator.dart          # Validação local de CPF
```

---

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| `SocketException ... Operation not permitted, errno = 1` (só no APK release) | Falta `INTERNET` no manifest **principal** | Adicionar `<uses-permission android:name="android.permission.INTERNET"/>` em `main/AndroidManifest.xml` |
| `Failed host lookup ... errno = 7` | DNS não resolve (hostname errado/inexistente) | Conferir a URL em `api_service.dart`; validar com `nslookup` |
| `CleartextNotPermitted` ao chamar `http://` | Cleartext bloqueado | `android:usesCleartextTraffic="true"` (ou migrar a API para `https://`) |
| `Connection refused` no emulador | Usando `localhost` em vez de `10.0.2.2` | Trocar `hostUrl` para `http://10.0.2.2:<porta>` |
| APK release "pequeno" (~55 MB vs ~160 MB) | Comparação com build **debug** | Comportamento normal do release (AOT + tree-shaking) |
| Acesso bloqueado ao cadastrar | CPF em conflito (HTTP 409) no backend | Verificar o cadastro do CPF no sistema/backend |
| Avisos de **Kotlin Gradle Plugin (KGP)** no build | Depreciação para versões futuras do Flutter | Apenas aviso; não quebra o build atual |

---

<sub>TosseCheck · app Flutter offline-first para registro de tosse de pets com retorno veterinário.</sub>
