# Nibble: запуск на сервере

Сервер: `149.154.68.183`, SSH: `root`, порт `22`. `7.vibe.fast.ru` — выданный ID сервера; для запуска используем IP.

Сайт: `http://149.154.68.183`. Запрос `/api/example` проксируется в backend как `/example`.

## GitHub Actions

Во всех трёх репозиториях открой **Settings → Secrets and variables → Actions → New repository secret** и добавь:

| Secret | Значение |
| --- | --- |
| `SSH_HOST` | `149.154.68.183` |
| `SSH_PRIVATE_KEY` | Полный приватный SSH-ключ, включая строки BEGIN и END; соответствующий публичный ключ уже должен быть добавлен на сервер |

Если ключ защищён passphrase, добавь secret `SSH_PASSPHRASE` и строку `passphrase: ${{ secrets.SSH_PASSPHRASE }}` рядом с `key:` в каждом workflow.

`SSH_PASSWORD` больше не нужен. Пароль базы и прочие настройки backend лежат в `.env` на сервере, для сборки образов они не нужны.

Во фронте и бэке: build → push в GHCR → deploy. Ветка `dev` и pull request запускают только build; `main` также публикует и разворачивает образ. В infra — только deploy.

## Docker-образы в GitHub

Образы публикуются автоматически workflow:

- `ghcr.io/yremancer/nibble_back:latest`
- `ghcr.io/zetlock17/nibble-frontend:latest`

Дополнительно сохраняется тег с SHA коммита. Вручную создавать образы или генерировать токен для публикации не нужно: используется встроенный `GITHUB_TOKEN` с `packages: write`.

После первой публикации открой **Packages → нужный пакет → Package settings → Change visibility → Public** у обоих владельцев. Сервер сможет скачивать публичные образы без токена.

Если образы должны остаться private, создай **Personal access token (classic)** с `read:packages` у аккаунта, имеющего доступ к обоим пакетам. На сервере один раз выполни `docker login ghcr.io -u ИМЯ_АККАУНТА` и вставь токен в запрос пароля. Если общего аккаунта с доступом нет, сначала предоставь ему доступ к обоим пакетам.

Справка: [публикация образов](https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images), [доступ к GHCR](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry).

## Первый запуск

1. На сервере должны быть установлены Git, Docker и Docker Compose plugin. Проверь `git --version`, `docker --version`, `docker compose version`. Установка Docker: [Ubuntu](https://docs.docker.com/engine/install/ubuntu/), [Debian](https://docs.docker.com/engine/install/debian/).
2. После согласования правок отправь изменения в соответствующие репозитории. Фронт и бэк должны попасть в `main`, чтобы появились образы. Их первый deploy не пройдёт, пока на сервере нет infra; после настройки его можно перезапустить.
3. Сделай оба пакета публичными или настрой `docker login`, как описано выше.
4. Подключись к серверу и подготовь infra:

```sh
ssh root@149.154.68.183
cd /root
git clone https://github.com/Yremancer/nibble_infra.git
cd nibble_infra
cp .env.example .env
chmod 600 .env
nano .env
```

В `.env` заполни `DB_PASSWORD`. Остальные значения уже настроены под Nibble. Пароль без специальных символов можно получить командой `openssl rand -hex 32`.

Если infra private, серверу нужен отдельный доступ на чтение GitHub-репозитория: например, deploy key и SSH URL `git@github.com:Yremancer/nibble_infra.git`. Ключ для входа Actions → сервер сам по себе не даёт серверу доступ к GitHub.

Запусти:

```sh
docker compose pull
docker compose up -d
docker compose ps
```

Открой `http://149.154.68.183`. Порт `80` должен быть доступен извне. HTTPS пока не настроен.

Дальше push в `main` infra обновляет конфигурацию через `git pull`, а push в `main` фронта или бэка пересобирает и обновляет соответствующий контейнер.
