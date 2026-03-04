#!/bin/bash

# Скрипт автоматизированной настройки инфраструктуры Alt Linux (Модуль 3)
# Использование: sudo ./alt_linux_autodeploy.sh [роль]
# Роли: hq-srv | br-srv | hq-rtr | br-rtr | isp

if [ "$EUID" -ne 0 ]; then
  echo "[-] Ошибка: Пожалуйста, запустите скрипт с правами root (sudo)."
  exit 1
fi

ROLE=$1

case $ROLE in 
  hq-srv)
    echo "[+] Начинаем настройку сервера HQ-SRV (IP: 192.168.0.1)..."

    # --- 2. ЦЕНТР СЕРТИФИКАЦИИ (CA) ---
    echo "[*] Настройка Центра Сертификации (ГОСТ)..."
    mkdir -p /etc/pki/CA/{private,certs,newcerts,crl}
    touch /etc/pki/CA/index.txt
    echo 1000 > /etc/pki/CA/serial
    chmod 700 /etc/pki/CA/private

    control openssl-gost enabled

    # Генерация корневых ключей
    openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:TCB -out /etc/pki/CA/private/ca.key
    openssl req -x509 -new -nodes -md_gost12_256 -key /etc/pki/CA/private/ca.key -out /etc/pki/CA/certs/ca.crt -days 3650 -subj "/CN=AU-TEAM Root CA"

    # Генерация ключей для сайтов
    openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:A -out /etc/pki/CA/private/web.au-team.irpo.key
    openssl genpkey -algorithm gost2012_256 -pkeyopt paramset:A -out /etc/pki/CA/private/docker.au-team.irpo.key

    # CSR и подписание для web
    openssl req -new -md_gost12_256 -key /etc/pki/CA/private/web.au-team.irpo.key -out /etc/pki/CA/newcerts/web.au-team.irpo.csr -subj "/CN=web.au-team.irpo"
    openssl x509 -req -in /etc/pki/CA/newcerts/web.au-team.irpo.csr -CA /etc/pki/CA/certs/ca.crt -CAkey /etc/pki/CA/private/ca.key -CAcreateserial -out /etc/pki/CA/certs/web.au-team.irpo.crt -days 30

    # CSR и подписание для docker
    openssl req -new -md_gost12_256 -key /etc/pki/CA/private/docker.au-team.irpo.key -out /etc/pki/CA/newcerts/docker.au-team.irpo.csr -subj "/CN=docker.au-team.irpo"
    openssl x509 -req -in /etc/pki/CA/newcerts/docker.au-team.irpo.csr -CA /etc/pki/CA/certs/ca.crt -CAkey /etc/pki/CA/private/ca.key -CAcreateserial -out /etc/pki/CA/certs/docker.au-team.irpo.crt -days 30

    # Копирование в NFS шару (если примонтирована)
    mkdir -p /raid/nfs/
    cp /etc/pki/CA/certs/{ca.crt,web.au-team.irpo.crt,docker.au-team.irpo.crt} /raid/nfs/ 2>/dev/null || echo "[-] Директория /raid/nfs не найдена, пропуск копирования"
    cp /etc/pki/CA/private/{web.au-team.irpo.key,docker.au-team.irpo.key} /raid/nfs/ 2>/dev/null
    chmod 777 /raid/nfs/*.key 2>/dev/null

    # --- 5. CUPS ---
    echo "[*] Настройка CUPS..."
    sed -i 's/Listen localhost:631/Listen hq-srv.au-team.irpo:631/' /etc/cups/cupsd.conf
    sed -i 's/#Order allow,deny/Allow any/g' /etc/cups/cupsd.conf
    systemctl restart cups

    # --- 6. RSYSLOG ---
    echo "[*] Настройка Rsyslog Сервера..."
    mkdir -p /opt/hq-rtr /opt/br-rtr /opt/br-srv
    cat << 'EOF' > /etc/rsyslog.d/00_common.conf
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
EOF
    systemctl enable --now rsyslog

    cat << 'EOF' > /etc/logrotate.conf
# see "man logrotate" for details
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
EOF
    systemctl enable --now logrotate.timer

    # --- 7. PROMETHEUS & GRAFANA ---
    echo "[*] Настройка Prometheus..."
    mkdir -p /etc/prometheus
    cat << 'EOF' > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9090', 'hq-srv:9100', 'br-srv:9100']
EOF
    systemctl enable --now prometheus-node_exporter 2>/dev/null
    systemctl enable --now prometheus 2>/dev/null
    systemctl enable --now grafana-server 2>/dev/null

    # --- 9. FAIL2BAN ---
    echo "[*] Настройка Fail2ban..."
    cat << 'EOF' > /etc/fail2ban/jail.local
[sshd]
enabled = true 
port    = 2026
logpath = /var/log/auth.log
backend = systemd
filter  = sshd 
action  = nftables[name=SSH, port=2026, protocol=tcp]
maxretry = 2
bantime = 1m
EOF
    systemctl enable --now fail2ban

    echo "[+] Настройка HQ-SRV завершена!"
    ;;

  br-srv)
    echo "[+] Начинаем настройку сервера BR-SRV (IP: 192.168.1.1)..."

    # --- 1. ИМПОРТ ПОЛЬЗОВАТЕЛЕЙ AD ---
    echo "[*] Импорт пользователей AD..."
    if [ ! -f "/mnt/Users.csv" ]; then
        echo "Монтируем образ..."
        mount /dev/sr0 /mnt/ 2>/dev/null
    fi

    cat << 'EOF' > /var/import.sh
#!/bin/bash
CSV_FILE="/mnt/Users.csv"

if [ ! -f "$CSV_FILE" ]; then
  echo "Файл Users.csv не найден!"
  exit 1
fi

while IFS=';' read -r fname lname role phone ou street zip city country password; do
    if [[ "$fname" == "First Name" ]]; then
        continue
    fi
    username=$(echo "${fname:0:1}${lname}" | tr '[:upper:]' '[:lower:]')
    sudo samba-tool ou create "OU=${ou},DC=AU-TEAM,DC=IRPO" --description="${ou} department" 2>/dev/null
    echo "Adding user: $username in OU=$ou"
    sudo samba-tool user add "$username" "$password" \
      --given-name="$fname" \
      --surname="$lname" \
      --job-title="$role" \
      --telephone-number="$phone" \
      --userou="OU=$ou" 2>/dev/null
done < "${CSV_FILE}"
echo "Complete import"
EOF
    chmod +x /var/import.sh
    /var/import.sh

    # --- 6. RSYSLOG КЛИЕНТ ---
    echo "[*] Настройка Rsyslog Клиента..."
    cat << 'EOF' > /etc/rsyslog.d/00_common.conf
module(load="imjournal")
module(load="imuxsock")
*.warn @@192.168.0.1:514
EOF
    systemctl enable --now rsyslog

    # --- 7. NODE EXPORTER ---
    echo "[*] Запуск Node Exporter..."
    systemctl enable --now prometheus-node_exporter

    # --- 8. ANSIBLE ---
    echo "[*] Подготовка Ansible Playbook..."
    mkdir -p /etc/ansible/PC-INFO
    cat << 'EOF' > /etc/ansible/get_hostname_address.yml
---
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
EOF
    chmod +x /etc/ansible/get_hostname_address.yml
    echo "[!] Чтобы запустить Ansible, выполните: ansible-playbook /etc/ansible/get_hostname_address.yml"
    
    echo "[+] Настройка BR-SRV завершена!"
    ;;

  hq-rtr|br-rtr)
    echo "[+] Начинаем настройку маршрутизатора ($ROLE)..."

    # --- 3. IPSEC ---
    echo "[*] Настройка IPsec GRE Tunnel..."
    if [ "$ROLE" == "hq-rtr" ]; then
        LEFT_IP="10.5.5.1"
        RIGHT_IP="10.5.5.2"
    else
        LEFT_IP="10.5.5.2"
        RIGHT_IP="10.5.5.1"
    fi

    cat << EOF > /etc/strongswan/ipsec.conf
conn gre
    type=tunnel
    authby=secret
    left=$LEFT_IP
    right=$RIGHT_IP
    leftprotoport=gre
    rightprotoport=gre
    auto=start
    pfs=no
EOF

    echo "10.5.5.1 10.5.5.2 : PSK \"P@ssw0rd\"" > /etc/strongswan/ipsec.secrets
    systemctl enable --now strongswan-starter.service

    # --- 4. NFTABLES ---
    echo "[*] Настройка nftables..."
    cat << 'EOF' > /etc/nftables/nftables.nft
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
EOF
    systemctl enable --now nftables
    systemctl restart nftables

    # --- 6. RSYSLOG КЛИЕНТ ---
    echo "[*] Настройка Rsyslog Клиента..."
    cat << 'EOF' > /etc/rsyslog.d/00_common.conf
module(load="imjournal")
module(load="imuxsock")
*.warn @@192.168.0.1:514
EOF
    systemctl enable --now rsyslog

    echo "[+] Настройка $ROLE завершена!"
    ;;

  isp)
    echo "[+] Начинаем настройку ISP..."
    
    # --- 2. NGINX SSL ПРОКСИ ---
    echo "[*] Настройка Nginx и поддержки ГОСТ..."
    control openssl-gost all
    mkdir -p /etc/nginx/ssl/private

    echo "[!] ВНИМАНИЕ: Скрипт не может сам скопировать сертификаты с HQ-SRV без пароля."
    echo "[!] Выполните копирование сертификатов (scp) вручную, затем обновите конфигурацию /etc/nginx/sites-available/"
    echo "[!] Не забудьте указать в конфиге Nginx:"
    echo "    ssl_ciphers GOST2012-KUZNYECHIK-KUZNYECHIKOMAC;"
    echo "    ssl_prefer_server_ciphers on;"
    ;;

  *)
    echo "Неизвестная роль. Доступные варианты:"
    echo "  hq-srv  - Настройка центрального сервера (CA, CUPS, Prometheus, Rsyslog Server, Fail2ban)"
    echo "  br-srv  - Настройка сервера филиала (AD Import, Ansible, Rsyslog Client)"
    echo "  hq-rtr  - Настройка роутера HQ (IPsec, nftables, Rsyslog Client)"
    echo "  br-rtr  - Настройка роутера BR (IPsec, nftables, Rsyslog Client)"
    echo "  isp     - Подготовка прокси ISP (Nginx SSL dirs)"
    exit 1
    ;;
esac

echo "[SUCCESS] Все операции скрипта завершены."
