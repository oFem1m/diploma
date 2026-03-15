# Сервер оптимизации — WebSocket API

Серверная часть программно-аппаратного комплекса визуализации результатов работы модификаций эволюционного алгоритма оптимизации. Принимает задачи по WebSocket, управляет очередью, выполняет вычисления, стримит прогресс клиенту.

## Структура проекта

```
server/
├── main.py                     # Точка входа (FastAPI + uvicorn)
├── config.py                   # Конфигурация сервера и лимиты
├── ws_handler.py               # Обработка WebSocket-соединений
├── requirements.txt            # Зависимости Python
├── protocol/
│   ├── types.py                # Pydantic-модели сообщений протокола
│   ├── envelope.py             # Сборка/разбор конвертов сообщений
│   └── validation.py           # Валидация payload задач
├── task_queue/
│   ├── job.py                  # Модель задачи и машина состояний
│   ├── job_queue.py            # Приоритетная очередь с идемпотентностью
│   └── worker.py               # Воркер — выполнение и стриминг прогресса
├── optimizer/
│   ├── objectives.py           # Целевые функции (builtin + expression)
│   ├── registry.py             # Реестр алгоритмов (name → class)
│   └── runner.py               # Обёртка запуска оптимизации
├── BBO/                        # Алгоритмы оптимизации
│   ├── BBO_classic/            # Классический BBO + модифицированный
│   ├── BBO_sinusoidal/         # Синусоидальный BBO + модифицированный
│   ├── BBO_mixed/              # Смешанный BBO + модифицированный
│   └── PSO/                    # Метод роя частиц
├── test_functions.py           # Тестовые функции (sphere, rastrigin, ackley, bukin6)
└── tests/                      # Тесты (pytest)
```

## Руководство администратора

### Требования

- Python >= 3.10
- Рекомендуется 3.12+

### Установка

```bash
cd server

# Создание виртуального окружения
python -m venv .venv

# Активация (Windows)
.venv\Scripts\activate

# Активация (Linux/Mac)
source .venv/bin/activate

# Установка зависимостей
pip install -r requirements.txt
```

### Запуск сервера

```bash
python main.py
```

Сервер запустится на `http://0.0.0.0:8765`. WebSocket endpoint: `ws://<host>:8765/ws/optimize`.

### Конфигурация

Параметры задаются в `config.py`:

| Параметр | По умолчанию | Описание |
|---|---|---|
| `host` | `0.0.0.0` | Адрес привязки |
| `port` | `8765` | Порт сервера |
| `max_queue_size` | `50` | Максимум задач в очереди |
| `max_workers` | `2` | Число параллельных воркеров |
| `default_timeout_ms` | `600000` | Таймаут задачи (10 мин) |
| `ping_interval_s` | `30` | Интервал keepalive ping |

Лимиты (класс `Limits`):

| Параметр | Значение | Описание |
|---|---|---|
| `max_generations` | `10000` | Максимум поколений |
| `max_pop_size` | `500` | Максимум размера популяции/роя |
| `max_dims` | `100` | Максимум измерений |

### Запуск тестов

```bash
# Установка тестовых зависимостей
pip install pytest pytest-asyncio

# Запуск всех тестов
python -m pytest tests/ -v

# Запуск конкретного модуля
python -m pytest tests/test_runner.py -v

# Только юнит-тесты (без сервера)
python -m pytest tests/ -v -k "not Integration"
```

### Проверка работоспособности

HTTP health-check:
```bash
curl http://localhost:8765/health
# {"status":"ok","workers":2,"queue_size":0}
```

### Мониторинг

Сервер выводит логи в stdout:
```
2026-03-15 23:07:40 [INFO] main: started 2 workers
2026-03-15 23:07:40 [INFO] task_queue.worker: worker worker-1 started
2026-03-15 23:07:41 [INFO] ws_handler: client connected
```

### Остановка

`Ctrl+C` — graceful shutdown, воркеры завершают текущие задачи.

## Протокол

Подробная документация: `protocol.md`

### Поддерживаемые алгоритмы

| Идентификатор | Описание |
|---|---|
| `bbo.classic` | Классический BBO (линейная миграция) |
| `bbo.classic.modified` | Классический BBO + адаптивная мутация, стагнация, локальный поиск |
| `bbo.sinusoidal` | BBO с синусоидальной миграцией |
| `bbo.sinusoidal.modified` | Синусоидальный BBO + адаптивная мутация |
| `bbo.mixed` | BBO со смешанной миграцией (линейная + синусоидальная) |
| `bbo.mixed.modified` | Смешанный BBO + адаптивная мутация |
| `pso` | Метод роя частиц |

### Целевые функции

| Тип | Описание |
|---|---|
| `builtin` | Встроенные: `sphere`, `rastrigin`, `ackley`, `bukin6` |
| `expression` | Строковое выражение: `x0*x0 + x1*x1` |

### Последовательность сообщений

```
Client → hello
Server → hello (capabilities)
Client → job.submit
Server → job.accepted
Server → job.started
Server → job.progress (×N)
Server → job.result
Server → job.finished
```

### Быстрый пример (Python)

```python
import asyncio, json, websockets

async def main():
    async with websockets.connect("ws://localhost:8765/ws/optimize") as ws:
        # Hello
        await ws.send(json.dumps({
            "header": {"v": 1, "type": "hello", "msg_id": "1", "ts": "2026-01-01T00:00:00Z",
                       "auth": {"scheme": "none", "token": None},
                       "trace": {"client_req_id": "h1", "job_id": None, "span_id": None},
                       "stream": {"stream_id": None, "seq": None, "total": None, "is_last": None},
                       "compression": {"algo": "none", "original_bytes": None}},
            "payload": {"client": {"name": "example"}, "wants": {"progress_stream": True}}
        }))
        print(json.loads(await ws.recv())["payload"]["capabilities"])

        # Submit
        await ws.send(json.dumps({
            "header": {"v": 1, "type": "job.submit", "msg_id": "2", "ts": "2026-01-01T00:00:00Z",
                       "auth": {"scheme": "none", "token": None},
                       "trace": {"client_req_id": "r1", "job_id": None, "span_id": None},
                       "stream": {"stream_id": None, "seq": None, "total": None, "is_last": None},
                       "compression": {"algo": "none", "original_bytes": None}},
            "payload": {
                "objective": {"kind": "builtin", "name": "rastrigin", "minimize": True},
                "problem": {"dims": 10, "bounds": {"kind": "uniform", "low": -5.12, "high": 5.12}},
                "method": {"name": "bbo.classic", "config": {"pop_size": 50, "max_generations": 200}},
                "streaming": {"mode": "every_k", "every_k": 10},
                "output": {"return_final_population": True}
            }
        }))

        while True:
            msg = json.loads(await ws.recv())
            t = msg["header"]["type"]
            if t == "job.progress":
                p = msg["payload"]["progress"]
                print(f"  iter {p['iteration']}/{p['max_iterations']} best_f={p['best_f']:.4f}")
            elif t == "job.result":
                print(f"Result: best_f={msg['payload']['result']['best_f']}")
            elif t == "job.finished":
                break

asyncio.run(main())
```
