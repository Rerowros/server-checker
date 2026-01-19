# VPS Server Checker 🖥️

Комплексный скрипт для тестирования VPS серверов. Проверяет доступность из РФ, IP геолокацию, блоклисты, DPI и многое другое.

## Возможности

- 📍 **IP геолокация** - определение страны, города, провайдера, ASN
- 🚫 **Блоклисты** - проверка RKN (Роскомнадзор) и DNSBL
- 🌐 **Сетевые тесты** - ping, порты, DNS, HTTP/HTTPS
- 🔍 **DPI детектирование** - TCP throttling (16-20), SNI фильтрация, QUIC
- 📊 **Доступность сервисов** - Google, YouTube, Telegram, и др.
- 📄 **Отчёты** - консоль, JSON, HTML

## Быстрый старт

### Один-командный запуск

```bash
curl -sSL https://raw.githubusercontent.com/YOUR_REPO/server-checker/main/install.sh | bash
```

### Локальная установка

```bash
git clone https://github.com/YOUR_REPO/server-checker.git
cd server-checker
chmod +x check-server.sh
./check-server.sh
```

## Использование

```bash
# Полная проверка
./check-server.sh

# Без speedtest (быстрее)
./check-server.sh --no-speedtest

# Без DPI тестов
./check-server.sh --no-dpi

# Сохранить HTML отчёт
./check-server.sh -f html -o report.html

# Сохранить JSON отчёт
./check-server.sh -f json -o report.json

# Увеличить таймаут (медленные сети)
./check-server.sh --timeout 30

# Подробный вывод
./check-server.sh --verbose
```

## Опции

| Опция                 | Описание                                  |
| --------------------- | ----------------------------------------- |
| `-h, --help`          | Показать справку                          |
| `-v, --version`       | Показать версию                           |
| `--verbose`           | Подробный вывод                           |
| `--timeout SEC`       | Таймаут сетевых тестов (по умолчанию: 10) |
| `--no-speedtest`      | Пропустить тест скорости                  |
| `--no-dpi`            | Пропустить DPI тесты                      |
| `-o, --output FILE`   | Сохранить отчёт в файл                    |
| `-f, --format FORMAT` | Формат: console, json, html               |

## Зависимости

### Обязательные

- `curl` - HTTP запросы

### Опциональные (расширяют функционал)

- `dig` или `nslookup` - DNS запросы
- `nc` (netcat) - тесты портов
- `openssl` - TLS/SNI тесты
- `jq` - парсинг JSON
- `mtr` или `traceroute` - трассировка маршрута
- `bc` - вычисления скорости
- `ipcalc` - проверка CIDR

### Установка зависимостей

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install curl dnsutils netcat-openbsd openssl jq mtr bc ipcalc
```

CentOS/RHEL:

```bash
sudo yum install curl bind-utils nc openssl jq mtr bc
```

## Структура проекта

```
server-checker/
├── check-server.sh    # Основной скрипт
├── lib/
│   ├── colors.sh      # Цветной вывод
│   ├── network.sh     # Сетевые утилиты
│   ├── blocklist.sh   # Проверка блоклистов
│   ├── dpi.sh         # DPI детектирование
│   └── report.sh      # Генерация отчётов
└── README.md
```

## Что проверяется

### 1. Информация о сервере

- Публичный IP адрес
- Геолокация (страна, город, регион)
- Провайдер и ASN
- PTR запись (reverse DNS)
- Информация о системе (OS, uptime)

### 2. Блоклисты

- **DNSBL** - zen.spamhaus.org, bl.spamcop.net, и др.
- **RKN** - список заблокированных IP Роскомнадзора

### 3. Сетевые тесты

- Ping до Google DNS, Cloudflare, Yandex
- Проверка открытых портов (80, 443, 22, 53)
- HTTP доступность сайтов
- Тест скорости скачивания

### 4. DPI Detection

- **TCP Throttling** - блокировка после 16-20 КБ (метод ТСПУ)
- **SNI Filtering** - фильтрация по TLS SNI
- **QUIC/UDP** - блокировка UDP протокола
- **DNS серверы** - доступность разных DNS

### 5. Доступность сервисов

- Google, YouTube, Telegram
- Facebook, Instagram, Twitter
- Discord, LinkedIn, TikTok, WhatsApp

## Пример вывода

```
═══════════════════════════════════════════════════════════════
  VPS Server Checker v1.0.0
═══════════════════════════════════════════════════════════════

▸ Collecting Server Information
───────────────────────────────────────────────────────────────
[✓] Public IP: 185.xxx.xxx.xxx
[✓] Location: Amsterdam, North Holland, NL
[✓] Provider: AS12345 Example Hosting
[✓] PTR: vps123.example.com

▸ Blocklist Checks
───────────────────────────────────────────────────────────────
[✓] DNSBL: Clean (not listed in 5 blocklists)
[✓] RKN: IP is not in the blocklist

▸ DPI Detection Tests
───────────────────────────────────────────────────────────────
[✓] TCP throttling: Not detected
[✓] SNI filtering: Not detected
[!] QUIC/UDP: Blocked or unsupported

═══════════════════════════════════════════════════════════════
📊 Summary
  Passed: 15  |  Failed: 0  |  Warnings: 2

✅ Server looks good! All tests passed.
```

## License

MIT License - используйте свободно.

## Disclaimer

⚠️ Этот скрипт предназначен для тестирования и исследовательских целей.
Вы несёте ответственность за соблюдение законов вашей юрисдикции.
