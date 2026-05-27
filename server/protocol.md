# WS JSON Protocol v1 — протокол оптимизации поверх WebSocket

## 1. Назначение

Протокол описывает обмен сообщениями по WebSocket между клиентом (Flutter/Dart) и сервером (Python) для постановки и выполнения задач оптимизации:

- клиент отправляет: целевую функцию, пространство поиска (размерность и границы), выбранный метод (семейство BBO и PSO) и конфигурацию метода;
- сервер возвращает: подтверждение постановки задачи, события очереди, поток прогресса выполнения и итоговый результат, включая диагностические метрики и (по запросу) большие массивы (популяции, позиции, скорости).

Протокол построен так, чтобы отражать данные, возвращаемые реализациями `optimize()` из проекта:
- общие поля результата: `best_x`, `best_f`, `history_best_f`;
- BBO: `final_population`, `final_fitness`;
- PSO: `final_positions`, `final_velocities`.

---

## 2. Транспорт и формат сообщений

### 2.1 WebSocket endpoint

Пример URL: `ws(s)://<host>/ws/optimize`

- формат данных: JSON (`application/json; charset=utf-8`);
- соединение долговременное; сообщения двунаправленные.

### 2.2 Ограничения размера сообщений и чанки

Сервер может ограничивать максимальный размер JSON-сообщения. Для передачи больших данных используется механизм чанков (`type="chunk"`), где данные дробятся на части и собираются клиентом по `stream_id`.

---

## 3. Единый конверт сообщения (Envelope)

Все сообщения имеют единый формат:

```json
{
  "header": {
    "v": 1,
    "type": "job.submit",
    "msg_id": "c1b0f3b6-4a8a-4b9c-86a6-7a3c2a3a0d8c",
    "ts": "2026-02-19T16:04:00.123Z",
    "session_id": null,
    "reply_to": null,
    "auth": { "scheme": "none", "token": null },
    "trace": { "client_req_id": "req-0001", "job_id": null, "span_id": null },
    "stream": { "stream_id": null, "seq": null, "total": null, "is_last": null },
    "compression": { "algo": "none", "original_bytes": null }
  },
  "payload": {}
}
```

### 3.1 Поля header

| Поле | Тип | Обязательное | Описание |
|---|---|---:|---|
| `v` | int | да | Версия протокола (текущая: 1) |
| `type` | string | да | Тип сообщения (см. раздел 4) |
| `msg_id` | string (UUID) | да | Уникальный идентификатор сообщения |
| `ts` | string (ISO 8601, UTC) | да | Время формирования сообщения |
| `session_id` | string/null | нет | Идентификатор сессии (при наличии) |
| `reply_to` | string/null | нет | `msg_id` сообщения, на которое это ответ |
| `auth` | object | да | Данные авторизации |
| `trace` | object | да | Идемпотентность и связь с `job_id` |
| `stream` | object | да | Параметры чанков (при необходимости) |
| `compression` | object | да | Информация о компрессии полезной нагрузки |

#### auth

```json
{ "scheme": "none|bearer|api_key", "token": "string|null" }
```

Если авторизация не используется: `scheme="none"`, `token=null`.

#### trace

```json
{ "client_req_id": "string", "job_id": "string|null", "span_id": "string|null" }
```

- `client_req_id` — ключ идемпотентности для `job.submit`. Клиент генерирует и повторно использует при ретраях.
- `job_id` — сервер проставляет после постановки задачи.
- `span_id` — опционально для трассировки (например, шаг/поколение).

#### stream (чанки)

```json
{ "stream_id": "string|null", "seq": "int|null", "total": "int|null", "is_last": "bool|null" }
```

Используется в сообщениях `chunk` и при ссылке на chunked-данные.

#### compression

```json
{ "algo": "none|gzip|zstd", "original_bytes": "int|null" }
```

Рекомендуется начинать с `none`. Если включается компрессия на уровне payload, клиент и сервер должны поддерживать выбранный алгоритм.

---

## 4. Типы сообщений (`header.type`)

### 4.1 Служебные

- `hello` — рукопожатие и обмен capabilities.
- `ping`, `pong` — keepalive (опционально).
- `error` — ошибка протокола, валидации или исполнения.
- `chunk` — часть больших данных.
- `cancel` — отмена задачи.
- `job.status.get` — запрос статуса задачи.
- `job.status` — ответ/пуш статуса задачи.

### 4.2 Основные для оптимизации

- `job.submit` — постановка задачи оптимизации.
- `job.accepted` — задача принята, выдан `job_id`.
- `job.queued` — обновления очереди (позиция/ETA).
- `job.started` — выполнение началось.
- `job.progress` — поток прогресса выполнения.
- `job.result` — итоговый результат и данные выполнения.
- `job.finished` — финальное событие завершения.

---

## 5. Рукопожатие (hello) и capabilities

### 5.1 Клиент → сервер: `hello`

```json
{
  "header": { "v": 1, "type": "hello", "msg_id": "...", "ts": "...", "reply_to": null,
    "auth": { "scheme": "none", "token": null },
    "trace": { "client_req_id": "hello-1", "job_id": null, "span_id": null },
    "stream": { "stream_id": null, "seq": null, "total": null, "is_last": null },
    "compression": { "algo": "none", "original_bytes": null }
  },
  "payload": {
    "client": { "name": "mobile-app", "version": "0.1.0", "platform": "android|ios", "lang": "dart" },
    "wants": { "progress_stream": true, "chunking": true }
  }
}
```

### 5.2 Сервер → клиент: `hello`

```json
{
  "header": { "v": 1, "type": "hello", "msg_id": "...", "ts": "...", "reply_to": "..." },
  "payload": {
    "server": { "name": "optimizer-server", "version": "0.1.0" },
    "capabilities": {
      "methods": [
        "bbo.classic",
        "bbo.classic.modified",
        "bbo.sinusoidal",
        "bbo.sinusoidal.modified",
        "bbo.mixed",
        "bbo.mixed.modified",
        "pso"
      ],
      "objective_kinds": ["builtin", "expression", "code_python"],
      "progress_modes": ["per_generation", "every_k", "none"],
      "max_payload_bytes": 1048576
    }
  }
}
```

---

## 6. Постановка задачи (job.submit)

### 6.1 Клиент → сервер: `job.submit`

```json
{
  "header": {
    "v": 1,
    "type": "job.submit",
    "msg_id": "6b2a8b1a-2ad2-4b64-a7cc-2bd918f1db31",
    "ts": "2026-02-19T16:04:00.123Z",
    "reply_to": null,
    "auth": { "scheme": "none", "token": null },
    "trace": { "client_req_id": "req-0001", "job_id": null, "span_id": null },
    "stream": { "stream_id": null, "seq": null, "total": null, "is_last": null },
    "compression": { "algo": "none", "original_bytes": null }
  },
  "payload": {
    "job": {
      "priority": "normal",
      "timeout_ms": 600000,
      "tags": ["diploma", "mobile"]
    },
    "objective": { "kind": "builtin", "name": "rastrigin", "minimize": true },
    "problem": {
      "dims": 10,
      "bounds": { "kind": "uniform", "low": -5.12, "high": 5.12 }
    },
    "method": {
      "name": "bbo.sinusoidal",
      "config": {
        "pop_size": 50,
        "max_generations": 200,
        "mutation_rate": 0.01,
        "elite_count": 2,
        "forbid_self_donation": true,
        "random_seed": 42
      }
    },
    "streaming": {
      "mode": "per_generation",
      "every_k": 1,
      "include": {
        "best_x": true,
        "best_f": true,
        "population": false,
        "fitness": false,
        "velocities": false
      },
      "max_points": {
        "history_best_f": 5000
      }
    },
    "output": {
      "return_final_population": true,
      "return_final_fitness": true,
      "return_final_velocities": false
    }
  }
}
```

### 6.2 Поле job

| Поле | Тип | Обязательное | Описание |
|---|---|---:|---|
| `priority` | `low|normal|high` | да | Приоритет в очереди |
| `timeout_ms` | int | нет | Таймаут выполнения задачи |
| `tags` | array(string) | нет | Метки для логов/аналитики |

---

## 7. Целевая функция (objective)

### 7.1 builtin (рекомендуется)

```json
{ "kind": "builtin", "name": "sphere", "minimize": true }
```

Поддерживаемые имена (минимум): `sphere`, `rastrigin`, `ackley`, `bukin6`.

### 7.2 expression (строковое выражение)

Переменные: `x0..x{dims-1}`.

```json
{ "kind": "expression", "expr": "x0*x0 + x1*x1", "minimize": true }
```

### 7.3 code_python (передача кода)

Использовать только при наличии ограничений/песочницы.

```json
{
  "kind": "code_python",
  "entrypoint": "objective",
  "expects": "batch",
  "code": "import numpy as np\n\ndef objective(X: np.ndarray):\n    return np.sum(X*X, axis=1)\n",
  "minimize": true
}
```

- `expects="batch"`: вход `X shape=(N,d)` → выход `shape=(N,)`.
- `expects="single"`: вход `x shape=(d,)` → выход `float` (сервер выполняет обёртку).

---

## 8. Пространство поиска (problem)

### 8.1 dims и bounds

```json
"problem": {
  "dims": 10,
  "bounds": { "kind": "uniform", "low": -5.12, "high": 5.12 }
}
```

#### bounds.kind = uniform

```json
{ "kind": "uniform", "low": -5.12, "high": 5.12 }
```

#### bounds.kind = per_dim

```json
{ "kind": "per_dim", "items": [[-5, 5], [-2, 2], [-10, 10]] }
```

Валидация: `len(items) == dims`, для каждого измерения `low < high`.

---

## 9. Метод и конфигурация (method)

### 9.1 Идентификаторы методов

- `bbo.classic`
- `bbo.classic.modified`
- `bbo.sinusoidal`
- `bbo.sinusoidal.modified`
- `bbo.mixed`
- `bbo.mixed.modified`
- `pso`

### 9.2 BBO (базовые поля конфигурации)

```json
{
  "pop_size": 50,
  "max_generations": 200,
  "mutation_rate": 0.01,
  "elite_count": 2,
  "forbid_self_donation": true,
  "random_seed": 42
}
```

Рекомендуемая валидация:
- `pop_size >= 2`
- `0 <= mutation_rate <= 1`
- `0 <= elite_count < pop_size`

### 9.3 PSO (базовые поля конфигурации)

```json
{
  "swarm_size": 50,
  "max_generations": 200,
  "w_start": 0.9,
  "w_end": 0.4,
  "c1": 2.0,
  "c2": 2.0,
  "vmax_frac": 0.2,
  "random_seed": 42
}
```

Рекомендуемая валидация:
- `swarm_size >= 2`
- `max_generations >= 1`
- `vmax_frac > 0`

---

## 10. Настройки стриминга (streaming)

```json
"streaming": {
  "mode": "per_generation|every_k|none",
  "every_k": 1,
  "include": {
    "best_x": true,
    "best_f": true,
    "population": false,
    "fitness": false,
    "velocities": false
  },
  "max_points": { "history_best_f": 5000 }
}
```

- `mode="per_generation"` — прогресс на каждом шаге.
- `mode="every_k"` — прогресс раз в `every_k` шагов.
- `mode="none"` — без прогресса, только `job.result`.
- `include.best_x` управляет наличием `progress.best_x`.
- `include.best_f` управляет наличием `progress.best_f` и `progress.history_best_f_tail`.
- `include.population`, `include.fitness` и `include.velocities` управляют одноимёнными полями в `snapshots`.

Рекомендуется по умолчанию отправлять только `best_x` и `best_f`, а большие массивы включать только при необходимости.

Поле `velocities` используется только для методов, в которых есть скорости частиц, например `pso`.

## 10.1 Настройки итогового результата (output)

```json
"output": {
  "return_final_population": true,
  "return_final_fitness": true,
  "return_final_velocities": false
}
```

- `return_final_population` управляет возвратом `final_population` для BBO и `final_positions` для PSO.
- `return_final_fitness` управляет возвратом `final_fitness`, если метод его формирует.
- `return_final_velocities` управляет возвратом `final_velocities` и используется только для PSO.

---

## 11. Ответы сервера: очередь и старт

### 11.1 job.accepted

Сервер подтверждает постановку задачи и возвращает `job_id`.

```json
{
  "header": { "v": 1, "type": "job.accepted", "msg_id": "...", "ts": "...", "reply_to": "..." ,
    "trace": { "client_req_id": "req-0001", "job_id": "job-8f3d1c", "span_id": null }
  },
  "payload": {
    "job_id": "job-8f3d1c",
    "state": "queued",
    "queue": { "position": 3, "eta_ms": 12000 }
  }
}
```

### 11.2 job.queued

Обновления позиции в очереди (может приходить несколько раз).

```json
{
  "header": { "v": 1, "type": "job.queued", "msg_id": "...", "ts": "...",
    "trace": { "client_req_id": "req-0001", "job_id": "job-8f3d1c", "span_id": null }
  },
  "payload": { "job_id": "job-8f3d1c", "queue": { "position": 1, "eta_ms": 4000 } }
}
```

### 11.3 job.started

```json
{
  "header": { "v": 1, "type": "job.started", "msg_id": "...", "ts": "...",
    "trace": { "client_req_id": "req-0001", "job_id": "job-8f3d1c", "span_id": null }
  },
  "payload": {
    "job_id": "job-8f3d1c",
    "started_at": "2026-02-19T16:04:05.000Z",
    "worker": { "id": "worker-1", "host": "srv-01" }
  }
}
```

---

## 12. Прогресс выполнения (job.progress)

### 12.1 Прогресс

```json
{
  "header": {
    "v": 1,
    "type": "job.progress",
    "msg_id": "...",
    "ts": "...",
    "trace": { "client_req_id": "req-0001", "job_id": "job-8f3d1c", "span_id": "iter-17" }
  },
  "payload": {
    "job_id": "job-8f3d1c",
    "progress": {
      "iteration": 17,
      "max_iterations": 200,
      "best_f": 12.345,
      "best_x": [0.1, -0.2, 0.0],
      "history_best_f_tail": [13.2, 12.9, 12.7, 12.345],
      "elapsed_ms": 950
    },
    "snapshots": {
      "population": null,
      "fitness": null,
      "velocities": null
    }
  }
}
```

Поля `best_f`, `best_x` и `history_best_f_tail` зависят от настроек `streaming.include`. Поле `history_best_f_tail` содержит только последние значения истории (например 10–100 значений), чтобы не пересылать всю историю на каждом шаге.

### 12.2 Ссылки на chunked-данные

Если включены `include.population`, `include.fitness` или `include.velocities`, сервер может отправить данные напрямую или ссылку на chunked-поток:

```json
{
  "header": { "v": 1, "type": "job.progress", "msg_id": "...", "ts": "...",
    "trace": { "client_req_id": "req-0001", "job_id": "job-8f3d1c", "span_id": "iter-17" }
  },
  "payload": {
    "job_id": "job-8f3d1c",
    "progress": { "iteration": 17, "max_iterations": 200, "best_f": 12.345, "elapsed_ms": 950 },
    "snapshots": {
      "population": { "ref_stream_id": "pop-job-8f3d1c-iter-17", "chunked": true },
      "fitness": null,
      "velocities": null
    }
  }
}
```

Далее сервер отправляет чанки `type="chunk"` с тем же `stream_id`.

---

## 13. Чанки больших данных (chunk)

### 13.1 Сообщение chunk

```json
{
  "header": {
    "v": 1,
    "type": "chunk",
    "msg_id": "...",
    "ts": "...",
    "trace": { "client_req_id": "req-0001", "job_id": "job-8f3d1c", "span_id": "iter-17" },
    "stream": { "stream_id": "pop-job-8f3d1c-iter-17", "seq": 0, "total": 2, "is_last": false }
  },
  "payload": {
    "kind": "ndarray",
    "shape": [50, 10],
    "dtype": "float64",
    "data": [[...], [...]]
  }
}
```

### 13.2 Сборка на клиенте

Клиент собирает чанки в порядке `seq` по ключу `stream_id` до `is_last=true` (или до `seq==total-1`, если `total` задан).

---

## 14. Итоговый результат (job.result)

### 14.1 Унифицированная структура результата

Обязательные поля:
- `best_x: number[dims]`
- `best_f: number`
- `history_best_f: number[]`

Опциональные поля:
- для BBO: `final_population`, `final_fitness`
- для PSO: `final_positions`, `final_velocities`

### 14.2 Пример результата BBO

```json
{
  "header": { "v": 1, "type": "job.result", "msg_id": "...", "ts": "...",
    "trace": { "client_req_id": "req-0001", "job_id": "job-8f3d1c", "span_id": null }
  },
  "payload": {
    "job_id": "job-8f3d1c",
    "result": {
      "best_x": [0.0, 0.0],
      "best_f": 0.00012,
      "history_best_f": [10.5, 8.2, 0.00012],
      "final_population": [[...], [...]],
      "final_fitness": [0.00012, 0.1]
    },
    "metrics": {
      "method": "bbo.sinusoidal",
      "iterations": 200,
      "evals": 200,
      "wall_time_ms": 5021,
      "seed": 42
    }
  }
}
```

### 14.3 Пример результата PSO

```json
{
  "header": { "v": 1, "type": "job.result", "msg_id": "...", "ts": "...",
    "trace": { "client_req_id": "req-0002", "job_id": "job-91aa10", "span_id": null }
  },
  "payload": {
    "job_id": "job-91aa10",
    "result": {
      "best_x": [0.01, -0.02],
      "best_f": 0.12,
      "history_best_f": [5.0, 3.2, 0.12],
      "final_positions": [[...], [...]],
      "final_velocities": [[...], [...]]
    },
    "metrics": {
      "method": "pso",
      "iterations": 200,
      "evals": 200,
      "wall_time_ms": 3890,
      "seed": 42
    }
  }
}
```

---

## 15. Финальное событие завершения (job.finished)

```json
{
  "header": { "v": 1, "type": "job.finished", "msg_id": "...", "ts": "...",
    "trace": { "client_req_id": "req-0001", "job_id": "job-8f3d1c", "span_id": null }
  },
  "payload": {
    "job_id": "job-8f3d1c",
    "final_state": "succeeded|failed|cancelled|timeout",
    "finished_at": "2026-02-19T16:04:10.100Z"
  }
}
```

---

## 16. Отмена задачи (cancel)

### 16.1 Клиент → сервер

```json
{
  "header": { "v": 1, "type": "cancel", "msg_id": "...", "ts": "...",
    "trace": { "client_req_id": "req-0001", "job_id": "job-8f3d1c", "span_id": null }
  },
  "payload": { "job_id": "job-8f3d1c", "reason": "user_cancel" }
}
```

### 16.2 Сервер → клиент

Сервер отправляет `job.finished` с `final_state="cancelled"` либо `error`, если отмена невозможна.

---

## 17. Запрос статуса (job.status.get / job.status)

### 17.1 Клиент → сервер: job.status.get

```json
{
  "header": { "v": 1, "type": "job.status.get", "msg_id": "...", "ts": "...",
    "trace": { "client_req_id": "req-0003", "job_id": "job-8f3d1c", "span_id": null }
  },
  "payload": { "job_id": "job-8f3d1c" }
}
```

### 17.2 Сервер → клиент: job.status

```json
{
  "header": { "v": 1, "type": "job.status", "msg_id": "...", "ts": "...", "reply_to": "...",
    "trace": { "client_req_id": "req-0003", "job_id": "job-8f3d1c", "span_id": null }
  },
  "payload": {
    "job_id": "job-8f3d1c",
    "state": "queued|running|succeeded|failed|cancelled|timeout",
    "queue": { "position": 1, "eta_ms": 4000 },
    "progress": { "iteration": 18, "max_iterations": 200, "best_f": 11.9 }
  }
}
```

---

## 18. Ошибки (error)

Единый формат ошибок:

```json
{
  "header": { "v": 1, "type": "error", "msg_id": "...", "ts": "...", "reply_to": "..." },
  "payload": {
    "code": "VALIDATION_ERROR",
    "message": "bounds.items length must equal dims",
    "details": { "field": "problem.bounds.items", "expected": 10, "got": 2 },
    "retryable": false
  }
}
```

### 18.1 Рекомендуемые коды ошибок

- `BAD_REQUEST`
- `VALIDATION_ERROR`
- `UNSUPPORTED_METHOD`
- `UNSUPPORTED_OBJECTIVE_KIND`
- `QUEUE_OVERFLOW`
- `JOB_NOT_FOUND`
- `JOB_ALREADY_FINISHED`
- `EXECUTION_ERROR`
- `TIMEOUT`
- `AUTH_REQUIRED`
- `AUTH_INVALID`

---

## 19. Контракт типов данных

### 19.1 Общие поля результата

- `best_x`: массив чисел длины `dims`
- `best_f`: число
- `history_best_f`: массив чисел

### 19.2 BBO

- `final_population`: массив размерности `pop_size x dims`
- `final_fitness`: массив длины `pop_size`

### 19.3 PSO

- `final_positions`: массив размерности `swarm_size x dims`
- `final_velocities`: массив размерности `swarm_size x dims`

---

## 20. Валидация на сервере (минимальные требования)

1. `problem.dims > 0`.
2. bounds:
   - `uniform`: `low < high`;
   - `per_dim`: `len(items) == dims` и для каждого измерения `low < high`.
3. BBO:
   - `pop_size >= 2`;
   - `0 <= mutation_rate <= 1`;
   - `0 <= elite_count < pop_size`.
4. PSO:
   - `swarm_size >= 2`;
   - `max_generations >= 1`;
   - `vmax_frac > 0`.
5. Сервер имеет право накладывать верхние лимиты (например на `max_generations`, размеры популяции/роя, таймауты).

---

## 21. Идемпотентность и повторные отправки

- Клиент обязан задавать `trace.client_req_id` в `job.submit`.
- Сервер должен обеспечивать идемпотентность: повторный `job.submit` с тем же `client_req_id` (в рамках одной учетной записи/сессии) не создает новую задачу, а возвращает существующий `job_id` и состояние.

---

## 22. Рекомендуемый сценарий обмена (последовательность)

1. Клиент → `hello`
2. Сервер → `hello` (capabilities)
3. Клиент → `job.submit`
4. Сервер → `job.accepted`
5. Сервер → `job.queued` (0..n раз)
6. Сервер → `job.started`
7. Сервер → `job.progress` (0..n раз)
8. Сервер → `job.result`
9. Сервер → `job.finished`

---

## 23. Замечания по безопасности для `code_python`

Если используется `objective.kind="code_python"`, рекомендуется:
- выполнять код в изолированной среде (процесс/контейнер);
- запретить сеть и доступ к файловой системе;
- ограничить CPU/RAM/time;
- использовать белый список импортов;
- включить строгий таймаут вычисления целевой функции.
