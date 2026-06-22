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

---

## Descrição COMPLETA (já com a seção Wear OS) — para colar na Ficha principal

A seção `⌚ ... Tile ... Complicação` entra logo após a lista de recursos e antes do
parágrafo "TempoRun foi feito para... / está diseñado para...".

### en-GB (completa)
```
This app is not a medical device and does not diagnose, treat or prevent any condition.

TempoRun is a running app built to help runners train better, track their progress, and make smarter decisions about training, races, and recovery.

With TempoRun, you can record your runs by GPS and track pace, distance, time, training history, and personal progress. Chat with SABER, an AI specialized in running, which answers your questions about biomechanics, nutrition, recovery, and injuries, helps generate tailored training plans, and supports your preparation for different goals.

Key features:

• Chat with SABER, an AI assistant specialized in running
• Personalized training plans based on your profile
• GPS run recording
• Training history and performance progress
• Analysis of pace, distance, time, and running metrics
• Personal records and progress tracking
• Search for races and running events
• Integration with health data and compatible wearables
• Educational biomechanical video analysis
• Content on recovery, race strategy, and sports nutrition
• Smart recommendations to support your training routine

⌚ On Wear OS (Galaxy Watch and compatible)
Train your runs straight from the watch: GPS, heart-rate zones, pace, cadence, splits, VO₂ max and race predictions. Your plan syncs from the phone.
• Tile: add TempoRun to your Smart Stack to see your weekly progress and next workout.
• Complication: put TempoRun on your watch face to track your weekly distance and start a run with a tap.

TempoRun is designed for beginner, intermediate, and advanced runners who want to better organize their training and improve with greater clarity.

The information provided by the app, including SABER's answers, is educational and intended to support your training. TempoRun does not replace medical advice or the assessment of a physical education professional, physical therapist, or nutritionist. Consult a qualified professional before starting or changing your training routine, especially in the case of injuries, symptoms, pre-existing conditions, or medication use.

Train smarter. Run with more confidence.
```

### pt-BR (completa)
```
Este app não é um dispositivo médico e não diagnostica, trata nem previne nenhuma condição.

O TempoRun é um app de corrida feito para ajudar corredores a treinar melhor, acompanhar sua evolução e tomar decisões mais inteligentes sobre treinos, provas e recuperação.

Com o TempoRun, você registra suas corridas por GPS e acompanha ritmo, distância, tempo, histórico de treinos e progresso pessoal. Converse com o SABER, uma IA especializada em corrida, que responde suas dúvidas sobre biomecânica, nutrição, recuperação e lesões, ajuda a gerar planos de treino personalizados e apoia sua preparação para diferentes objetivos.

Principais recursos:

• Converse com o SABER, um assistente de IA especializado em corrida
• Planos de treino personalizados com base no seu perfil
• Registro de corridas por GPS
• Histórico de treinos e evolução de desempenho
• Análise de ritmo, distância, tempo e métricas de corrida
• Recordes pessoais e acompanhamento do progresso
• Busca por provas e eventos de corrida
• Integração com dados de saúde e wearables compatíveis
• Análise educativa de vídeo da biomecânica
• Conteúdos sobre recuperação, estratégia de prova e nutrição esportiva
• Recomendações inteligentes para apoiar sua rotina de treinos

⌚ No Wear OS (Galaxy Watch e compatíveis)
Treine corrida direto do relógio: GPS, FC com zonas, ritmo, cadência, splits, VO₂ máx e predição de provas. O plano é sincronizado do celular.
• Bloco (Tile): adicione o TempoRun à Smart Stack para ver o progresso da semana e o próximo treino.
• Complicação: coloque o TempoRun no mostrador para acompanhar os km da semana e iniciar a corrida com um toque.

O TempoRun foi feito para corredores iniciantes, intermediários e avançados que querem organizar melhor seus treinos e evoluir com mais clareza.

As informações fornecidas pelo app, incluindo as respostas do SABER, têm caráter educativo e servem para apoiar seus treinos. O TempoRun não substitui orientação médica nem a avaliação de um profissional de educação física, fisioterapeuta ou nutricionista. Consulte um profissional qualificado antes de iniciar ou mudar sua rotina de treinos, especialmente em casos de lesões, sintomas, condições preexistentes ou uso de medicamentos.

Treine com mais inteligência. Corra com mais confiança.
```

### es-419 (completa)
```
Esta app no es un dispositivo médico y no diagnostica, trata ni previene ninguna condición.

TempoRun es una app de running creada para ayudar a los corredores a entrenar mejor, seguir su progreso y tomar decisiones más inteligentes sobre entrenamientos, carreras y recuperación.

Con TempoRun puedes registrar tus carreras por GPS y seguir el ritmo, la distancia, el tiempo, el historial de entrenamientos y tu progreso personal. Conversa con SABER, una IA especializada en running que responde tus dudas sobre biomecánica, nutrición, recuperación y lesiones, ayuda a generar planes de entrenamiento personalizados y apoya tu preparación para distintos objetivos.

Funciones principales:

• Conversa con SABER, un asistente de IA especializado en running
• Planes de entrenamiento personalizados según tu perfil
• Registro de carreras por GPS
• Historial de entrenamientos y progreso de rendimiento
• Análisis de ritmo, distancia, tiempo y métricas de carrera
• Récords personales y seguimiento del progreso
• Búsqueda de carreras y eventos de running
• Integración con datos de salud y wearables compatibles
• Análisis educativo de video de la biomecánica
• Contenidos sobre recuperación, estrategia de carrera y nutrición deportiva
• Recomendaciones inteligentes para apoyar tu rutina de entrenamiento

⌚ En Wear OS (Galaxy Watch y compatibles)
Entrena tus carreras directo desde el reloj: GPS, zonas de FC, ritmo, cadencia, parciales, VO₂ máx y predicción de tiempos. El plan se sincroniza desde el teléfono.
• Mosaico (Tile): agrega TempoRun a tu Smart Stack para ver tu progreso semanal y el próximo entrenamiento.
• Complicación: coloca TempoRun en la esfera del reloj para seguir tus km de la semana e iniciar una carrera con un toque.

TempoRun está diseñado para corredores principiantes, intermedios y avanzados que quieren organizar mejor sus entrenamientos y mejorar con mayor claridad.

La información que ofrece la app, incluidas las respuestas de SABER, tiene fines educativos y sirve para apoyar tus entrenamientos. TempoRun no sustituye el consejo médico ni la evaluación de un profesional de educación física, fisioterapeuta o nutricionista. Consulta a un profesional calificado antes de iniciar o cambiar tu rutina de entrenamiento, especialmente en caso de lesiones, síntomas, condiciones preexistentes o uso de medicamentos.

Entrena con más inteligencia. Corre con más confianza.
```
