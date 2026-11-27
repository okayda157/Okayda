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
Sem o construtor BVH em tempo real (`VICTORY_BVH_BUILDER=0`), o shader original `CS_ScreenProbes_TemporalResolve` deixa ruído binário (blocos brancos e pretos) em ambientes internos e áreas escuras, enquanto a oclusão de vincos esmagava rostos, braços e armários para `#000000`.

- **Anti-manchas em interiores:** teto configurável sobre o histórico de probes (`VICTORY_AMBIENT_CAP`, padrão `1.55` em vez de `4.0`) e mistura controlada (`VICTORY_AMBIENT_KEEP`, padrão `0.55`) com rejeição suave de picos aberrantes (`trust = keep_was * saturate(2.5 - has / top)`).
- **Fim das sombras e personagens `#000000`:** piso suave na oclusão de vincos (`open = lerp(0.38, 1.0, ...)`) com viés de plano mais limpo (`- 0.010 * c.z - 0.015`) e raio de amostragem ampliado no `gather` (`0.55 + 0.006 * p.z * p.z`).
- **Visibilidade noturna e em cômodos escuros:** preenchimento hemisférico mínimo (`VICTORY_AMBIENT_FLOOR`, padrão `0.045`), atenuado automaticamente ao ar livre sob luz direta forte (`1 / (1 + lum * 5.0)`).
- **Névoa interna controlada:** `VICTORY_AMBIENT_AIR=1.2` limita o espalhamento volumétrico em cômodos fechados.

### 2. Proteção Anti-OOM, Shared RAM e VRAM ([`residency.rs`](crates/victory-gpu/src/residency.rs), [`pool.rs`](crates/victory-gpu/src/pool.rs), [`shadow.rs`](crates/victory-gpu/src/shadow.rs), [`list.rs`](crates/victory-gpu/src/list.rs), [`host.rs`](crates/victory-gpu/src/host.rs))
- Monitoramento contínuo de pressão em memória compartilhada (`NON_LOCAL` / `Shared RAM`) via DXGI (`shared_pressure_for` / `host_shared_pressure`) e liberação proativa (`reclaim_memory_for_oom`) com fallback em blocos menores no `relay` e `card_back`.
- Desacoplamento do trimming de pools, snapshots, command allocators/lists e etapas de placa quando `VICTORY_RESIDENCY=0`, eliminando crashes de memória em sessões longas (sessões contínuas de mais de 1h37m validadas sem crash).
- Integração com **Direct3D 12 Agility SDK 1.620** e registro automático de sessões/relatórios via [scripts/Run-WithErrorLog.ps1](scripts/Run-WithErrorLog.ps1).

### 3. Otimizações de CPU e Submissão ([`resource.rs`](crates/victory-gpu/src/resource.rs), [`draw.rs`](crates/victory-gpu/src/draw.rs), [`host.rs`](crates/victory-gpu/src/host.rs))
- **Evicção incremental de texturas (`resource::let_go_idle`):** substituída a varredura bloqueante de todas as texturas quando a VRAM passava do alvo (`38–87 ms` por sweep) por cursor rotativo (`FROM_EVICT`) limitado a `24.576` itens e `2.5 ms` de orçamento.
- **Passagem paralela do heap de buffers (`draw::heap_buffer_pass`):** redução paralela de `spans` em blocos (`8192` via `land::each_view`), lotes de `512` slots e remoção de alocação desnecessária em `unwatched` quando `VICTORY_UNWATCHED_FRAMES=1`.
- **Cadência adaptativa de sweep (`host::sweep`):** `2000 ms` fora de pressão e `1000 ms` sob `residency::pressured()`.
- **Silenciamento de flood no log:** filtro `victory_gpu::port_descriptors=error` no launcher elimina >120 mil linhas repetidas de `WARN` por sessão mantendo erros críticos, GPU/VRAM e métricas de submissão intactas.

### 4. Perfil Padrão de Execução ([`Play-VIctory.cmd`](Play-VIctory.cmd))

| Switch | Valor Padrão | Função |
|---|---|---|
| `VICTORY_OUTPUT` / `VICTORY_UPSCALER` / `VICTORY_RENDER_SCALE` | `1280x720` / `6` / `0.85` | Resolução alvo enxuta para RX 6600 com upscaler próprio do título |
| `VICTORY_VRAM_TARGET_PERCENT` / `VICTORY_VRAM_EVICT_PERCENT` / `VICTORY_POOL_KEEP_PERCENT` | `84` / `88` / `82` | Mantém uso saudável dentro do orçamento de `~7.2 GB` sem thrashing |
| `VICTORY_THIN_THREADS` / `VICTORY_UNDER_THREADS` / `VICTORY_VIEW_THREADS` / `VICTORY_LAND_THREADS` | `10` / `8` / `8` / `10` | Saturação balanceada para 10c/20t no Xeon E5-2650 v3 |
| `VICTORY_ASK_EARLY` | `4` | Antecipa consultas de `write watch` fora da thread de submissão |
| `VICTORY_AMBIENT` / `VICTORY_AMBIENT_SHADE` / `VICTORY_AMBIENT_AIR` | `1.0` / `0.55,0.45` / `1.2` | Ativa iluminação ambiente estimada com vincos suaves e ar interno limpo |
| `VICTORY_AMBIENT_CAP` / `VICTORY_AMBIENT_KEEP` / `VICTORY_AMBIENT_FLOOR` | `1.55` / `0.55` / `0.045` | Contém manchas brancas de probes e garante leitura em cenas escuras |
| `VICTORY_AMBIENT_SETTLE` | `250,3,2.0` | Adaptação rápida ao entrar/sair de interiores |
| `VICTORY_PORT_CONSTANTS` / `VICTORY_PORT_DESCRIPTORS` / `VICTORY_PORT_CBV` / `VICTORY_PORT_GUARD` / `VICTORY_PORT_JOURNAL` | `1` | Patches de portabilidade PC para constantes, descritores, CBVs, guardas e journal |
| `VICTORY_RESIDENCY` / `VICTORY_LOG` | `0` / filtro enxuto | Sem limitador artificial de upload e sem flood de `port_descriptors` |

---

## Como compilar e usar

Pré-requisitos: Windows 10/11 x64 (CPU AVX2), GPU Direct3D 12 (SM 6.6 + Mesh Shaders), Rust toolchain + MSVC Build Tools, e sua pasta própria contendo `game_scarlett_master.exe`.

```powershell
# 1. Compilar binário otimizado
cargo build --release --locked -p victory

# (Opcional) Compilar perfil com diagnósticos completos / DRED
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
