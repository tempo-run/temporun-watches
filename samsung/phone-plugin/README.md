# Plugin do celular — ponte Wear OS ↔ temporun-app (Capacitor)

Lado **celular** da Fase 2. Mora aqui por simetria com o lado iOS
(`apple/PhoneSessionManager.swift` também é código do app, versionado neste repo), mas é
**integrado no `temporun-app/android`** — não é compilado pelo módulo `:wear`.

Equivale, no Android, ao trio iOS `PhoneSessionManager` + `CredentialSyncToWatch`
(+ `PlanSyncToWatch`/`ComplicationSyncToWatch` nas Fases 3–4).

## Arquivos

| Arquivo | Papel |
|---------|-------|
| `WearWorkoutListenerService.kt` | `WearableListenerService`: recebe a corrida (`/temporun/workout`) e chama a edge function `watch-workout-save`. Funciona com o app fechado. |
| `WearBridgePlugin.kt` | Plugin Capacitor `WearBridge`: o JS passa as credenciais Supabase (`setCredentials`) para o nativo guardar. |

## Decisão de arquitetura (D1)

O serviço grava **chamando a edge function** (Caminho b), não fazendo ponte para o JS nem
INSERT direto. O corpo do POST é o JSON do contrato montado **no relógio**
(`WorkoutPayload.toSupabaseMap().toJsonString()`) — o celular só repassa verbatim. Assim a
lógica de XP/streak/recordes e o schema vivem num único lugar (servidor).

## Passos de integração no `temporun-app/android`

1. **Dependência** (já presente em apps Capacitor recentes; senão, no `app/build.gradle`):
   ```gradle
   implementation "com.google.android.gms:play-services-wearable:19.0.0"
   ```

2. **Copiar** os dois `.kt` para o pacote `com.temporun.run.wear` do app
   (`android/app/src/main/java/com/temporun/run/wear/`).

3. **Registrar o serviço** no `android/app/src/main/AndroidManifest.xml`, dentro de
   `<application>`:
   ```xml
   <service
       android:name="com.temporun.run.wear.WearWorkoutListenerService"
       android:exported="true">
       <intent-filter>
           <action android:name="com.google.android.gms.wearable.DATA_CHANGED" />
           <action android:name="com.google.android.gms.wearable.MESSAGE_RECEIVED" />
           <data android:scheme="wear" android:host="*"
                 android:pathPrefix="/temporun" />
       </intent-filter>
   </service>
   ```

4. **Registrar o plugin** Capacitor: em apps Capacitor com autoload, basta a anotação
   `@CapacitorPlugin`. Se o app registra plugins manualmente, adicionar
   `registerPlugin(WearBridgePlugin.class)` na `MainActivity`.

5. **No JS** (`temporun-app`), após login e a cada refresh de sessão Supabase:
   ```js
   import { registerPlugin } from '@capacitor/core'
   const Wear = registerPlugin('WearBridge')
   const { data: { session } } = await supabase.auth.getSession()
   if (session) {
     // grava no celular (relay) E envia ao relógio (standalone, Fase 5)
     await Wear.setCredentials({
       url: SUPABASE_URL, anonKey: SUPABASE_ANON_KEY,
       accessToken: session.access_token, refreshToken: session.refresh_token,
       userId: session.user.id,
     })
   }
   // no logout (limpa no celular e no relógio):
   await Wear.clearCredentials()

   // quando o plano ativo mudar (Fase 3):
   await Wear.syncPlan({ plan: JSON.stringify(planoAtivoRow) })
   ```

6. **`applicationId`**: o app de relógio (`samsung/wear`) e o app do celular já usam o MESMO
   `com.temporun.run` — requisito do Data Layer para pareamento.

## Pré-requisitos de backend

- Migração `samsung/supabase/wear_migration.sql` aplicada.
- Edge function **`watch-workout-save-samsung`** criada (variante Wear; a do Apple fica intacta).
- Ver `samsung/supabase/BACKEND_DEPLOY.md`.

## Pendências (próximas fases)

- **Fase 2.1:** emitir evento para o JS quando a corrida é salva (XP/streak/recordes) e nos
  live updates, para a UI do app reagir.
- **Fase 5:** fila offline no celular + refresh de token no 401 (hoje só loga o erro).
- **Fase 3/4:** `syncPlan()` e `syncComplication()` no plugin (envio celular→relógio).
