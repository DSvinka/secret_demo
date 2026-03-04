# Демо-Экзамен - Модуль 3

## СКРИПТ ДЛЯ ЗАПУСКА НА ЭКЗАМЕНЕ.
Его выполнять нужно на машине, которую хотите настроить.
Выполнять от пользователя - рута. Можно по SSH, можно по Proxmox
```sh
 bash <(curl https://dsvinka.ru/demo/part-3-script.sh) {имя машины}

# Пример:
 bash <(curl -s https://dsvinka.ru/demo/part-3-script.sh) hq-srv

# Скрипт автоматизированной настройки
# Использование: bash <(curl -s https://dsvinka.ru/demo/part-3-script.sh) [роль]
# Роли: hq-srv | br-srv | hq-rtr | br-rtr | isp
```
После выполнение нужно делать clear или просто рестарт машины делать.

## 1. Импорт пользователей на сервере BR-SRV

Монтируем образ с данными:

```sh
mount /dev/sr0 /mnt/
```

Создаем скрипт для импорта пользователей:

```sh
nano /var/import.sh
```

**Содержимое `/var/import.sh` (исправлены опечатки и кавычки):**

```sh
#!/bin/bash
CSV_FILE="/mnt/Users.csv"
DOMAIN="AU-TEAM.IRPO"
ADMIN_USER="Administrator"
ADMIN_PASS="P@ssw0rd"

while IFS=';' read -r fname lname role phone ou street zip city country password; do
    if [[ "$fname" == "First Name" ]]; then
        continue
    fi
    username=$(echo "${fname:0:1}${lname}" | tr '[:upper:]' '[:lower:]')
    sudo samba-tool ou create "OU=${ou},DC=AU-TEAM,DC=IRPO" --description="${ou} department"
    echo "Adding user: $username in OU=$ou"
    sudo samba-tool user add "$username" "$password" \
      --given-name="$fname" \
      --surname="$lname" \
      --job-title="$role" \
      --telephone-number="$phone" \
      --userou="OU=$ou"
done < "${CSV_FILE}"

echo "Complete import"
```

Делаем скрипт исполняемым и запускаем:

```sh
chmod +x /var/import.sh
/var/import.sh
```

_Проверка: через утилиту ADMC проверяем появление пользователей и OU._

---
## 2. Настройка центра сертификации на базе HQ-SRV

> Если выводит ошибку что пакеты openssl не установлены, устанавливаем:
> ```sh
> apt-get update && apt-get install openssl ca-certificates -y
> ```

Создаем структуру каталогов:
```sh
mkdir -p /etc/pki/CA/{private,certs,newcerts,crl}
touch /etc/pki/CA/index.txt
echo 1000 > /etc/pki/CA/serial
chmod 700 /etc/pki/CA/private
```

Включаем поддержку ГОСТ в ОС Альт:
```sh
control openssl-gost enabled
```

Создание корневого ключа и сертификата (CA):
```sh
openssl genpkey \
  -algorithm gost2012_256 \
  -pkeyopt paramset:TCB \
  -out /etc/pki/CA/private/ca.key

openssl req -x509 -new -nodes \
  -md_gost12_256 \
  -key /etc/pki/CA/private/ca.key \
  -out /etc/pki/CA/certs/ca.crt \
  -days 3650 \
  -subj "/CN=AU-TEAM Root CA"
```

Создание ключей и запросов (CSR) для сайтов:
```sh
openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:A -out /etc/pki/CA/private/web.au-team.irpo.key

openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:A -out /etc/pki/CA/private/docker.au-team.irpo.key

openssl req -new -md_gost12_256 \
  -key /etc/pki/CA/private/web.au-team.irpo.key \
  -out /etc/pki/CA/newcerts/web.au-team.irpo.csr \
  -subj "/CN=web.au-team.irpo"

openssl req -new -md_gost12_256 \
  -key /etc/pki/CA/private/docker.au-team.irpo.key \
  -out /etc/pki/CA/newcerts/docker.au-team.irpo.csr \
  -subj "/CN=docker.au-team.irpo"
```

Подписание сертификатов для сайтов (добавлены пропущенные слэши `\` переноса строк):
```sh
openssl x509 -req \
  -in /etc/pki/CA/newcerts/web.au-team.irpo.csr \
  -CA /etc/pki/CA/certs/ca.crt \
  -CAkey /etc/pki/CA/private/ca.key \
  -CAcreateserial \
  -out /etc/pki/CA/certs/web.au-team.irpo.crt \
  -days 30

openssl x509 -req \
  -in /etc/pki/CA/newcerts/docker.au-team.irpo.csr \
  -CA /etc/pki/CA/certs/ca.crt \
  -CAkey /etc/pki/CA/private/ca.key \
  -CAcreateserial \
  -out /etc/pki/CA/certs/docker.au-team.irpo.crt \
  -days 30
```

### Сертификатный выкидыш:
Копируем нужные сертификаты и ключи в хранилище. 
```sh
cp /etc/pki/CA/certs/ca.crt /raid/nfs/
cp /etc/pki/CA/certs/web.au-team.irpo.crt /raid/nfs/
cp /etc/pki/CA/certs/docker.au-team.irpo.crt /raid/nfs/
cp /etc/pki/CA/private/web.au-team.irpo.key /raid/nfs/
cp /etc/pki/CA/private/docker.au-team.irpo.key /raid/nfs/
chmod 777 /raid/nfs/web.au-team.irpo.key
chmod 777 /raid/nfs/docker.au-team.irpo.key
```

Копируем теперь на ISP.
```sh
# ЭТО КОМАНДЫ НА ISP ВЫПОЛНЯЮТСЯ
mkdir /etc/nginx/ssl
scp -P 2026 sshuser@172.16.1.1:/raid/nfs/web.au-team.irpo.crt /etc/nginx/ssl/
scp -P 2026 sshuser@172.16.1.1:/raid/nfs/web.au-team.irpo.key /etc/nginx/ssl/
scp -P 2026 sshuser@172.16.1.1:/raid/nfs/docker.au-team.irpo.key /etc/nginx/ssl/
scp -P 2026 sshuser@172.16.1.1:/raid/nfs/docker.au-team.irpo.crt /etc/nginx/ssl/

```

На клиентах помещаем `ca.crt` в `/etc/pki/ca-trust/source/anchors` и выполняем обновление сертификатов.
  ```sh
cp /mnt/nfs/ca.crt /etc/pki/ca-trust/source/anchors
update-ca-trust
  ```

На ISP включаем поддержку ГОСТ: 
```sh
control openssl-gost all
```

### Конфигурация Nginx на ISP (обратный прокси):
В конфигурационных файлах сайтов (`web` и `docker`) исправьте блок `server`
```nginx
listen 443 ssl;
ssl_certificate /etc/nginx/ssl/web.au-team.irpo.crt; 
	# Для докера ставим: docker.au-team.irpo.crt
ssl_certificate_key /etc/nginx/ssl/web.au-team.irpo.key; 
	# Для докера ставим: docker.au-team.irpo.key
ssl_protocols TLSv1.2;
ssl_ciphers GOST2012-KUZNYECHIK-KUZNYECHIKOMAC;
ssl_prefer_server_ciphers on;
```

Перезапуск:
```sh
systemctl restart nginx
```

---
## 3. Настройка IPsec (Шифрование поверх GRE)

На обеих маршрутизаторах (HQ-RTR и BR-RTR) редактируем файл `ipsec.conf`:

```sh
nano /etc/strongswan/ipsec.conf
```

Добавляем:
```conf
conn gre
    type=tunnel
    authby=secret
    left=10.5.5.1
    right=10.5.5.2
    leftprotoport=gre
    rightprotoport=gre
    auto=start
    pfs=no
```
IP-адреса left и right зеркально меняются на противоположном роутере

На обеих маршрутизаторах редактируем файл с паролями:
```sh
nano /etc/strongswan/ipsec.secrets
```

Добавляем строку:
```c
10.5.5.1 10.5.5.2 :PSK "P@ssw0rd"
```

Включаем и запускаем службу:
```sh
systemctl enable --now strongswan-starter.service 
```

Проверка на роутере: 
```sh
tcpdump -i ens18 -n -p esp
```

---
## 4. Настройка межсетевого экрана (nftables) на HQ-RTR и BR-RTR

```sh
nano /etc/nftables/nftables.nft
```

Приводим таблицу фильтров к такому виду:
```nft
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        log prefix "Dropped Input: " level debug
        iif lo accept
        ct state established,related accept
        tcp dport { 22,514,53,80,443,3015,445,139,88,2026,8080,2049,389 } accept
        udp dport { 53,123,500,4500,88,137,8080,2049 } accept
        ip protocol icmp accept
        ip protocol esp accept
        ip protocol gre accept
        ip protocol ospf accept
    }
    chain forward {
        type filter hook forward priority 0; policy drop;
        log prefix "Dropped forward: " level debug
        iif lo accept
        ct state established,related accept
        tcp dport { 22,514,53,80,443,3015,445,139,88,2026,8080,2049,389 } accept
        udp dport { 53,123,500,4500,88,137,8080,2049 } accept
        ip protocol icmp accept
        ip protocol esp accept
        ip protocol gre accept
        ip protocol ospf accept
    }
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
```

НА BR-RTR ДЕЛАЕМ АНАЛОГИЧНО
## 5. Настройка принт-сервера CUPS на HQ-SRV

```sh
nano /etc/cups/cupsd.conf
```
- Заменить `Listen localhost:631` на `Listen hq-srv.au-team.irpo:631`
- В блоках `<Location />`, `<Location /admin>` и `<Location /admin/conf>` закомментировать `#Order allow,deny` и вписать `Allow any`

Перезагрузка службы:
```sh
systemctl restart cups
```

Настройка клиента: 
- Зайти по адресу `https://hq-srv.au-team.irpo:631`.
- Авторизоваться как `root`. 
- Добавить виртуальный PDF принтер (CUPS-PDF), поставив галочку "Разрешить совместный доступ". 
- В пункте "Создать" выбираем "Generic", "Модель" выбираем "Generic CUPS-PDF"
- На клиентской ОС добавить найденный сетевой принтер через утилиту "Принтеры", вписав имя сервера hq-srv.

## 6. Логирование (Rsyslog) на HQ-RTR, BR-RTR, BR-SRV

**Настройка Сервера логов (HQ-SRV):**

```sh
nano /etc/rsyslog.d/00_common.conf
```

```sh
module(load="imjournal")
module(load="imuxsock")
module(load="imtcp")
input(type="imtcp" port="514")

if $fromhost-ip contains '192.168.0.62' then {
  *.warn /opt/hq-rtr/hq-rtr.log
}
if $fromhost-ip contains '10.5.5.2' then {
  *.warn /opt/br-rtr/br-rtr.log
}
if $fromhost-ip contains '192.168.1.1' then {
  *.warn /opt/br-srv/br-srv.log
}
```

Создаем каталоги логов и перезапускаем службу:
```sh 
mkdir -p /opt/hq-rtr /opt/br-rtr /opt/br-srv
systemctl enable --now rsyslog
```

**Настройка Клиентов (HQ-RTR, BR-RTR, BR-SRV):**
В файле `/etc/rsyslog.d/00_common.conf` раскомментировать модули `imjournal` и `imuxsock` и добавить:
```sh
*.warn @@192.168.0.1:514
```

Перезапуск: 
```sh
systemctl enable --now rsyslog
```

**Настройка Ротации логов (на сервере):**
```sh
nano /etc/logrotate.conf
```

Добавить в конец файла:
```
/opt/hq-rtr/*.log
/opt/br-rtr/*.log
/opt/br-srv/*.log
{
    minsize 10M
    rotate 4
    weekly
    compress
    missingok
}
```

_Примечание: logrotate в systemd запускается через таймер, поэтому правильная команда для автозапуска:_

```sh
systemctl enable --now logrotate.timer
logrotate -d /etc/logrotate.conf
```

---
## 7. Мониторинг (Prometheus + Grafana)

Запуск node_exporter на клиентских машинах:
```sh
systemctl enable --now prometheus-node_exporter
```

Настройка Prometheus на HQ-SRV:
```sh
nano /etc/prometheus/prometheus.yml
```

В блоке `static_configs` приводим к виду (одинарные прямые кавычки!):
```yml
    static_configs:
      - targets: ['localhost:9090', 'hq-srv:9100', 'br-srv:9100']
```

Запуск служб:
```sh
systemctl enable --now grafana-server
systemctl enable --now prometheus
systemctl enable --now prometheus-node_exporter
```

Настройка Grafana: 
- Заходим на `http://hq-srv:3000` (admin/admin), 
- меняем пароль на P@ssw0rd
- Заходим в профиль пользователя (правый верхний угол с авой рандомной), "Profile" и меняем язык на русский.
- В меню "Подключения" в пункте "Источники данных" нажимаем "Добавить источник данных"
- Выбираем Prometheus, адрес сборщика задаем https://localhost:9090 (Server URL)
- В меню "Дашборды" создаём дашборд.
- Выбираем импорт дашборка и указываем 11074.
- Выбираем службу для дашборда Prometheus. Нажимаем Импорт.
- Заходим в меню на 3 точки, выбираем редактировать и переименовываем заголовок на "Информация по серверам"
- Happy Happy Happy

## 8. Инвентаризация через Ansible

```sh
mount /dev/sr0 /mnt/
cp /mnt/playbook/get_hostname_address.yml /etc/ansible/
chmod +x /etc/ansible/get_hostname_address.yml
```

Редактируем Playbook (строго соблюдаем отступы):
```sh
nano /etc/ansible/get_hostname_address.yml
```

```yml
- name: Инвентаризация
  hosts: HQ-SRV, HQ-CLI
  tasks:
    - name: Получение данных с хоста
      copy:
        dest: "/etc/ansible/PC-INFO/{{ ansible_hostname }}.yml"
        content: |
          Hostname: {{ ansible_hostname }}
          IP_Address: {{ ansible_default_ipv4.address }}
      delegate_to: localhost
```

Создаем директорию и запускаем:
```sh
mkdir -p /etc/ansible/PC-INFO
ansible-playbook /etc/ansible/get_hostname_address.yml
```

Проверка: 
```sh
cat /etc/ansible/PC-INFO/hq-srv.yml
```
## 9. Защита SSH с помощью Fail2ban
Редактируем файл конфигурации (можно создать `/etc/fail2ban/jail.local` или править `jail.conf`):
```sh
nano /etc/fail2ban/jail.conf
```

Находим секцию `[sshd]` и приводим к виду:
```ini
[sshd]
enabled = true 
port    = 2026
logpath = /var/log/auth.log
backend = systemd
filter  = sshd 
action  = nftables[name=SSH, port=2026, protocol=tcp]
maxretry = 2
bantime = 1m
```

Включаем службу:
```sh
systemctl enable --now fail2ban
```

Проверка статуса после попыток неправильного ввода пароля по ssh:
```sh
fail2ban-client status sshd
```
