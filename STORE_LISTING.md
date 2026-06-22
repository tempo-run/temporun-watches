# TempoRun — correções da revisão Wear OS (rejeição 21/jun/2026)

A revisão Wear OS rejeitou por **2 motivos de metadados** (não de código). Não precisa de
novo build — corrija os textos/declarações abaixo e reenvie para revisão.

---

## 1) "Descrição não menciona o bloco nem a complicação"

O app inclui um **Bloco (Tile)** (`TempoRunTileService`) e uma **Complicação**
(`TempoRunComplicationService`), mas a descrição da loja não os menciona. **Solução:**
adicione esta seção à descrição em cada idioma (Detalhes do app → Descrição completa).

### pt-BR
```
⌚ No Wear OS (Galaxy Watch e compatíveis)
Treine corrida direto do relógio: GPS, FC com zonas, ritmo, cadência, splits, VO₂ máx e predição de provas. O plano é sincronizado do celular.
• Bloco (Tile): adicione o TempoRun à Smart Stack para ver o progresso da semana e o próximo treino.
• Complicação: coloque o TempoRun no mostrador para acompanhar os km da semana e iniciar a corrida com um toque.
```

### en-GB
```
⌚ On Wear OS (Galaxy Watch and compatible)
Train your runs straight from the watch: GPS, heart-rate zones, pace, cadence, splits, VO₂ max and race predictions. Your plan syncs from the phone.
• Tile: add TempoRun to your Smart Stack to see your weekly progress and next workout.
• Complication: put TempoRun on your watch face to track your weekly distance and start a run with a tap.
```

### es-419
```
⌚ En Wear OS (Galaxy Watch y compatibles)
Entrena tus carreras directo desde el reloj: GPS, zonas de FC, ritmo, cadencia, parciales, VO₂ máx y predicción de tiempos. El plan se sincroniza desde el teléfono.
• Mosaico (Tile): agrega TempoRun a tu Smart Stack para ver tu progreso semanal y el próximo entrenamiento.
• Complicación: coloca TempoRun en la esfera del reloj para seguir tus km de la semana e iniciar una carrera con un toque.
```

---

## 2) "Não foi possível acessar com as credenciais de login"

O relógio **não tem login próprio**: ele recebe as credenciais do **celular** via Data Layer,
e o login só habilita a sincronização na nuvem (as funções principais — correr, métricas,
Bloco e Complicação — funcionam **sem login**). O revisor travou numa tela de login (provável
login do app do celular) com credenciais que não funcionaram.

**Solução:** Conteúdo do app → **Acesso ao app** → forneça credenciais que REALMENTE funcionam
+ as instruções abaixo. Verifique antes que a conta loga de fato (a do print falhou).

### Instruções para o revisor (cole no campo de instruções)
```
The TempoRun Wear OS app has NO separate sign-in screen and does not gate its core features
behind login. On the watch you can start a run and use all live metrics (GPS, heart rate,
zones, pace, cadence, splits, VO₂ max, race predictions), the Tile and the Complication
WITHOUT signing in.

Sign-in is done once on the paired phone app (TempoRun, same package com.temporun.run).
After signing in on the phone, the watch receives the account credentials automatically via
the Wear Data Layer; this only enables optional cloud sync of completed runs.

To review with full sync enabled:
1. Install the TempoRun phone app and sign in with the test account below.
2. Open TempoRun on the paired watch — credentials sync automatically.

Test account:
Email: apptemporun@gmail.com
Password: <INSIRA UMA SENHA VÁLIDA E TESTADA>
```

---

## Reenvio
1. Corrija (1) a descrição nos 3 idiomas e (2) o Acesso ao app.
2. Não precisa de novo bundle — os dois são metadados.
3. Visão geral da publicação → **Enviar para revisão**.
