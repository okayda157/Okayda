# Okayda — VIctory Otimizado (AMD RX 6600 & Xeon)

Build otimizada mantida por **Okayda** sobre o [VIctory](https://github.com/Marvisak/VIctory) e o fork AMD [Belobug/VIctory-Belobug-AMD](https://github.com/Belobug/VIctory-Belobug-AMD), ajustada para entregar estabilidade prolongada sem OOM, iluminação limpa sem manchas/sombras pretas e maior taxa de quadros em GPUs AMD de 8 GB.

> **Aviso:** este repositório não contém arquivos, códigos nem assets do jogo. Você precisa da sua própria cópia legal (`game_scarlett_master.exe` e arquivos do título). Sem afiliação ou endosso da desenvolvedora/publicadora.

---

## Configuração do PC de Testes (Okayda)

Build desenvolvida, testada e validada nesta configuração real:

| Componente | Especificação |
|---|---|
| **Sistema Operacional** | Microsoft Windows 10 Pro (`10.0.19041` x64) |
| **Processador (CPU)** | Intel Xeon E5-2650 v3 @ 2.30 GHz (`10` núcleos / `20` threads) |
| **Memória (RAM)** | `32 GB` DDR4 (`~31.8 GiB` utilizáveis) |
| **Placa de Vídeo (GPU)** | AMD Radeon RX 6600 (`8147 MB` VRAM dedicada / `~7.2 GB` DXGI budget) |

---

## O que foi modificado nesta build

### 1. Iluminação Ambiente, Sombras e Remoção de Manchas ([`crates/victory-gpu/src/ambient.rs`](crates/victory-gpu/src/ambient.rs))
Sem o construtor BVH em tempo real (`VICTORY_BVH_BUILDER=0`), o shader original `CS_ScreenProbes_TemporalResolve` deixa ruído binário (blocos brancos e pretos) em ambientes internos e áreas escuras, enquanto a oclusão de vincos esmagava rostos, interiores e fachadas na sombra para `#000000`.

- **Anti-manchas com preservação de céu/luz:** teto configurável sobre o histórico de probes (`VICTORY_AMBIENT_CAP`, padrão `2.8`) e mistura controlada (`VICTORY_AMBIENT_KEEP`, padrão `0.65`) com rejeição suave de picos aberrantes (`trust = keep_was * saturate(3.2 - has / top)`).
- **Fim das casas e interiores `#000000`:** `mean()` agora calcula média ponderada pelas células iluminadas (`lit_sum / lit_w` com `80%` de peso) para que céu/paredes em `0.0` não zerem a radiância ambiente; piso suave na oclusão (`open = lerp(0.64, 1.0, ...)`) e piso diurno proporcional (`0.42 * cells[CELLS].rgb`), iluminando construções na sombra (ex.: fachadas sem sol direto) sem lavar áreas claras.
- **Visibilidade real em salas escuras sem lâmpada:** preenchimento hemisférico mínimo (`VICTORY_AMBIENT_FLOOR`, padrão `0.35` / perfil `0.45`), atenuado suavemente em zonas claras (`1 / (1 + lum * 1.1)`).
- **Névoa interna controlada:** `VICTORY_AMBIENT_AIR=0.7` limita o espalhamento volumétrico em cômodos fechados.

### 2. Retenção de Áreas Visitadas, Anti-OOM e VRAM ([`residency.rs`](crates/victory-gpu/src/residency.rs), [`pool.rs`](crates/victory-gpu/src/pool.rs), [`shadow.rs`](crates/victory-gpu/src/shadow.rs), [`list.rs`](crates/victory-gpu/src/list.rs), [`host.rs`](crates/victory-gpu/src/host.rs))
- Monitoramento contínuo de pressão em memória compartilhada (`NON_LOCAL` / `Shared RAM`) via DXGI (`shared_pressure_for` / `host_shared_pressure`) e liberação proativa (`reclaim_memory_for_oom`) com fallback em blocos menores no `relay` e `card_back`.
- **Menos re-streaming ao voltar para locais já visitados:** `vram_keep_with_thresholds` e `vram_idle_ms` em [`host.rs`](crates/victory-gpu/src/host.rs) sobem os tempos ociosos para `45s` / `15s` com poda incremental menor perto do alvo, combinados com `VICTORY_VRAM_TARGET_PERCENT=93`, `VICTORY_VRAM_EVICT_PERCENT=97`, `VICTORY_TEXTURE_ROOM_PERCENT=96`, `VICTORY_STAGING_KEPT=4` e `VICTORY_CARD_BUFFERS_MIN_KB=1024` / `VICTORY_CARD_BUFFERS_MB=512` (devolve centenas de MB de VRAM às texturas e corta dezenas de passes de comparação/readback na placa).
- Desacoplamento do trimming de pools, snapshots e allocators quando `VICTORY_RESIDENCY=0`, eliminando crashes de memória em sessões longas.
- **Streaming rápido sem inanição no áudio/CPU:** `VICTORY_TEXTURE_STAGE_MB=640`, `VICTORY_EARLY_TEXTURES_MS=32`, `VICTORY_TEXTURE_LOOK_MS=400` e remoção de `VICTORY_TITLE_PRIORITIES=0` para que as threads de streaming não fiquem presas em prioridade `IDLE`.
- Integração com **Direct3D 12 Agility SDK 1.620** e registro automático via [scripts/Run-WithErrorLog.ps1](scripts/Run-WithErrorLog.ps1).

### 3. Otimizações de CPU, Sincronização e Submissão ([`resource.rs`](crates/victory-gpu/src/resource.rs), [`draw.rs`](crates/victory-gpu/src/draw.rs), [`host.rs`](crates/victory-gpu/src/host.rs))
- **Eliminação de fila em `host::mapped()`:** coalescência por ticket atômico (`MAPPED_NEEDED` / `MAPPED_DONE`) e liberação do mutex antes do `WaitForSingleObject`, reduzindo stalls serializados na fila de cópia D3D12 ao criar texturas/buffers em várias threads.
- **Evicção incremental de texturas (`resource::let_go_idle`):** cursor rotativo (`FROM_EVICT`) limitado a `24.576` itens e `2.5 ms` de orçamento.
- **Passagem de buffers enxuta (`draw::heap_buffer_pass`):** rotação `HEAP_ROUND = 64`, redução paralela de `spans`, lotes de `512` slots e menos alocações em `unwatched`.
- **Folga para áudio e render no Xeon 10c/20t:** workers calibrados (`4 / 4 / 4 / 4`, `3` de pipeline) + `VICTORY_LAND_SKIP=1`, reduzindo saturação de CPU em 98% que causava engasgos no mixer de áudio.
- **Cadência adaptativa de sweep (`host::sweep`):** `2000 ms` fora de pressão e `1000 ms` sob `residency::pressured()`.
- **Silenciamento de flood no log:** filtro `victory_gpu::port_descriptors=error` no launcher.

### 4. Perfil Padrão de Execução ([`Play-VIctory.cmd`](Play-VIctory.cmd))

| Switch | Valor Padrão | Função |
|---|---|---|
| `VICTORY_OUTPUT` / `VICTORY_UPSCALER` / `VICTORY_RENDER_SCALE` | `3840x2160` / `6` / `0.67` | Saída `4K` fixa com upscaler próprio do título (`2560x1440` interno -> `3840x2160` HUD e tela) |
| `VICTORY_TEXTURE_ROOM_PERCENT` / `VICTORY_VRAM_TARGET_PERCENT` / `VICTORY_VRAM_EVICT_PERCENT` / `VICTORY_POOL_KEEP_PERCENT` | `96` / `93` / `97` / `92` | Mantém áreas visitadas em VRAM por muito mais tempo antes de liberar sob pressão |
| `VICTORY_CARD_BUFFERS_MIN_KB` / `VICTORY_CARD_BUFFERS_MB` / `VICTORY_STAGING_KEPT` | `1024` / `512` / `4` | Mantém apenas buffers grandes (`>= 1 MiB`) na VRAM, liberando espaço para texturas e cortando comparações/readbacks na GPU |
| `VICTORY_TEXTURE_STAGE_MB` / `VICTORY_EARLY_TEXTURES_MS` / `VICTORY_TEXTURE_LOOK_MS` | `640` / `32` / `400` | Drena filas de streaming rapidamente ao virar ou mover a câmera |
| `VICTORY_THIN_THREADS` / `VICTORY_UNDER_THREADS` / `VICTORY_VIEW_THREADS` / `VICTORY_LAND_THREADS` / `VICTORY_LAND_SKIP` / `VICTORY_TITLE_PRIORITIES` | `4` / `4` / `4` / `4` / `1` / `1` | Equilibra workers em 10 cores físicos deixando CPU livre para áudio e threads de streaming do jogo |
| `VICTORY_ASK_EARLY` | `4` | Antecipa consultas de `write watch` fora da thread de submissão |
| `VICTORY_AMBIENT` / `VICTORY_AMBIENT_SHADE` / `VICTORY_AMBIENT_AIR` | `1.35` / `0.35,0.45` / `0.7` | Iluminação ambiente forte em sombras/construções com vincos limpos e névoa contida |
| `VICTORY_AMBIENT_CAP` / `VICTORY_AMBIENT_KEEP` / `VICTORY_AMBIENT_FLOOR` | `2.8` / `0.65` / `0.45` | Preserva luz do céu em fachadas sombreadas e garante leitura clara em salas sem luz |
| `VICTORY_AMBIENT_SETTLE` | `250,3,2.0` | Adaptação rápida ao entrar/sair de interiores |
| `VICTORY_PORT_CONSTANTS` / `VICTORY_PORT_DESCRIPTORS` / `VICTORY_PORT_CBV` / `VICTORY_PORT_GUARD` / `VICTORY_PORT_JOURNAL` | `1` | Patches de portabilidade PC para constantes, descritores, CBVs, guardas e journal |
| `VICTORY_RESIDENCY` / `VICTORY_LOG` | `0` / filtro enxuto | Sem limitador artificial de upload e sem flood de `port_descriptors` |

---

## Ponte automática para a pasta do jogo (Usuários e IAs)

Não é necessário editar caminhos na mão nem quebrar em pastas com espaços (ex.: `C:\jogos hidra\GTA6.Xbox.v1.0.2.1-CYBERLEEK`). O launcher [`Play-VIctory.cmd`](Play-VIctory.cmd) resolve `game_scarlett_master.exe` via [`scripts/Resolve-GameExe.ps1`](scripts/Resolve-GameExe.ps1) nesta ordem:

1. **Arrastar e soltar / argumento:** arraste a pasta do jogo (ou o próprio `game_scarlett_master.exe`) para cima do `Play-VIctory.cmd`, ou rode `Play-VIctory.cmd "C:\caminho\do\jogo"` (salva automaticamente em `.victory-game-dir`, ignorado pelo git).
2. **Variável de ambiente:** `VICTORY_GAME_DIR` (pasta do jogo ou caminho completo do `.exe`).
3. **Config local:** arquivo `.victory-game-dir` na raiz ou `[paths] game_dir` em `victory.toml`.
4. **Auto-detecção nos discos locais:** procura pastas vizinhas (`..\GTA6*`) e varre os discos fixos locais (`1–2` níveis), salvando `.victory-game-dir` na primeira execução.
5. **Ponte em 1 comando (ideal para IAs e automação):**
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\Link-Game.ps1 -Path "C:\jogos hidra\GTA6.Xbox.v1.0.2.1-CYBERLEEK" -Run
   ```
   (Sem `-Path`, o `Link-Game.ps1` localiza o jogo sozinho, grava `.victory-game-dir` + `victory.toml` e, com `-Run`, abre o `Play-VIctory.cmd` direto.)

---

## Como compilar e usar

Pré-requisitos: Windows 10/11 x64 (CPU AVX2), GPU Direct3D 12 (SM 6.6 + Mesh Shaders) e sua pasta própria contendo `game_scarlett_master.exe`.

- **Modo rápido (sem precisar instalar Rust):** ao rodar **`Play-VIctory.cmd`** em um download novo do GitHub, o script [`scripts/Ensure-Runner.ps1`](scripts/Ensure-Runner.ps1) baixa automaticamente o pacote pré-compilado (`Okayda-win64-release.zip`, gerado pelo GitHub Actions em [`.github/workflows/release.yml`](.github/workflows/release.yml) com `victory.exe` + `D3D12\D3D12Core.dll` 1.620.2) — ou compila localmente se você tiver `cargo` instalado.

```powershell
# Compilação manual (opcional, requer Rust + MSVC Build Tools)
cargo build --release --locked -p victory

# Perfil com diagnósticos completos / DRED
cargo build --profile diag --locked -p victory --features diagnostics
```

1. Coloque o dump em `..\GTA6.Xbox.v1.0.2.1\game_scarlett_master.exe` (ou defina `VICTORY_GAME_DIR`).
2. Rode **`Play-VIctory.cmd`** para jogar com HUD (`F3` alterna) e gravação automática de pipelines.
   - `Play-VIctory.cmd diag` abre com DRED e métricas completas.
   - `Play-VIctory.cmd safe` desativa os ports experimentais mantendo `VICTORY_PORT_CBV` e controle de VRAM.
3. *(Opcional)* Use `scripts\Warm-AllPipelines.cmd` para pré-aquecer pipelines já registrados no driver AMD após trocar de driver ou atualizar a build.

Documentação técnica adicional herdada da base encontra-se em [docs/README-fxceless.md](docs/README-fxceless.md).

---

## Créditos

- **Okayda** — otimizações de VRAM/Shared RAM e prevenção de OOM, remoção de gargalos de CPU em sweeps/heaps, ajustes do shader de iluminação ambiente/sombras e perfil de execução para RX 6600 & Xeon.
- **[VIctory](https://github.com/Marvisak/VIctory)** — projeto base: loader, serviços de runtime, recompilador de shaders e backend Direct3D 12.
- **[Belobug (VIctory-Belobug-AMD)](https://github.com/Belobug/VIctory-Belobug-AMD)** — fork base AMD, workers de pipeline e implementação original do stand-in de luz ambiente.

---

## Licença

Distribuído sob **GPL-3.0-or-later**, conforme o projeto base VIctory. Consulte [LICENSE](LICENSE) e [docs/asset-policy.md](docs/asset-policy.md).
