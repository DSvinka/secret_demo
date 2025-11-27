> P.S. Автор писал методичку ночью, с 3 недельным недосыпом, температурой, и больной бошкой.  
> По этому в тексте встречается нецензурная брань и попытки поднять "кукуху" со дна всякими шутками. 
> Но методичка работает и не содержит ошибок, как у Бондарчука.   
> Не судите строго. Спасибо.  
---

# TASK 1. Настройка Samba
---
## BR-SRV
```bash
# Если команда samba-tool не найдена 
apt-get install -y task-samba-dc

rm -f /etc/samba/smb.conf

samba-tool domain provision --use-rfc2307 --interactive
	enter (x5)
	P@ssw0rd
	P@ssw0rd

cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
	y
systemctl enable --now samba
reboot
```

## HQ-CLI
```bash
su -
nano /etc/resolv.conf
	search au-team.irpo
	nameserver 192.168.3.2
	# Замените ^^^^^^^^^^^ 
	# НА ВАШ IP адрес BR-SRV
```

Заходим в "Центр Управления Системой"
Нажимаем "Аутентификация"
Ставим галку "Домен Active Directory"

> Если галка ~~такая сука~~ не ставится, то необходимо установить samba-client.
> ```bash
> apt-get update | apt-get install -y task-auth-ad-sssd
> ```
> и затем просто закрываем окно "Аутентификация" и открываем заново

Вписываем:
- Домен: AU-TEAM.IRPO
- Рабочая группа: AU-TEAM
- Имя компьютера: HQ-CLI
- SSSD

Нажимаем "Применить"
В открывшемся окне "Имя пользователя" оставляем без изменений, пароль устанавливаем `P@ssw0rd`

В консоль рекомендуется вписать 
```bash
kinit Administrator
	P@ssw0rd
```

Затем в списке приложений найдем ADMC (либо открыть через консоль написав команду `admc`)

> Если его ~~ПО КАКОЙ ТО ЕБУЧЕЙ ПРИЧИНЕ~~ нету, то необходимо его установить.
> `apt-get install -y admc`

Там переходим в "au-team.irpo" -> "Computers"
Нажимаем ПКМ и выбираем "Создать" -> "Пользователь"
- Имя: hquser1
- Полное имя: hquser1
- Имя для входа: hquser1
- Имя для входа (до Windows 2000): hquser1
- Пароль: P@ssw0rd
- Убераем все галки кроме "Пароль не истекает"

И так создаем 2-3 пользователя, меня цифру в имени.

Потом нажимаем ПКМ и выбираем "Создать" -> "Группа"
- Имя: hq
- Имя группы: hq
- Область группы: Глобальная
- Тип группы: Безопасность

Затем дважды нажимаем ЛКМ по группе "hq" и выбираем вкладку "Участники". Там нажимаем "Добавить" и в поле "Имя:" вписываем имя "hquser", нажимаем "Добавить", в открывшемся окне, через SHIFT выделяем всех hquser'ов и нажимаем "Добавить"
![[Pasted image 20251127031310.png]]

Затем нажимаем ОК, ОК, ОК

Открываем снова консоль и пишем
```bash
nano /etc/sudoers
	%au-team//hq ALL=(ALL) NOPASSWD:/bin/cat,/bin/grep,/bin/id
```

TASK 1 PROFIT, YAPPYYYYYY

# TASK 2. Сконфигурировать файловое хранилище
---
## HQ-SRV

Первым делом нужно убедится что на HQ-SRV вообще есть диск `/dev/sdb` и `/dev/sdc`
Для этого прописываем `lsblk` и смотрим на выхлоп, должно быть два раздела по 1G весом.
![[Pasted image 20251127032528.png]]

> Если их нет, то в **Proxmox**, в разделе "Hardware" нажимаем "Add" и выбираем "Hard Disk".
> Там меняем только размер на 1 и указываем Storage (он на стендах один)
> И так 2 раза, чтобы создать 2 раздела.

Далее пишем
```bash
fdisk /dev/sdb
	g
	n
	Enter (x3)
	w
	
fdisk /dev/sdc
	g
	n
	Enter (x3)
	w
```

И снова блюём командами в консось

```bash
mdadm --create --verbose /dev/md0 -l 0 -n 2 /dev/sdb1 /dev/sdc1
mdadm --detail --scan >> /etc/mdadm.conf

mkfs.ext4 /dev/md0
mkdir /raid
chmod 777 /raid

mount -t ext4 /dev/md0 /raid
nano /etc/fstab
	/dev/md0 /raid ext4 defaults 0 0
mount -av
```

Happy Happy Happy

# TASK 3. Настраиваем файловые сервер NFS
---
## HQ-SRV

Ну погнали снова блевать командами)
```bash
mkdir /raid/nfs
chmod 777 /raid/nfs
nano /etc/exports
	/raid/nfs 192.168.1.0/26(rw,sync,subtree_check)
	# Вот тут я если честно не понял
	# какой IP имел ввиду бондарь, но 
	# предполагаю что имелась введу сеть HQ-CLI
	# у меня это 192.168.1.0/26 а вы ставьте те 
	# цифры, которые в вашей сети 
systemctl enable --now nfs
exportfs -a
```

> И снова рубрика "Что делать если у меня не стоит?"
> Если `systemctl enable --now nfs` выдает ошибку то тут нужно ~~молится~~ прописать 
> `apt-get install -y nfs-server`
> И у вас встанет, даже виагра не потребуется :D

## HQ-CLI

Это к сожалению не всё, нужно ещё клиент настроить...
```bash
mkdir /mnt/nfs
chmod 777 /mnt/nfs
nano /etc/fstab
	192.168.0.2:/raid/nfs /mnt/nfs nfs auto 0 0
	# Это мой адрес к HQ-SRV, меняйте на свой!
mount -av
```

## HQ-SRV

Если последняя команда на HQ-CLI (`mount -av`) выдает ошибку, перезагружаем nfs сервер на hq-srv
```bash
systemctl restart nfs
```

> Можно ещё проверить что всё работает создав файл с HQ-SRV через `touch` (`touch /raid/nfs/guinea.pig`)
> и проверив появление этого файла с HQ-CLI через `ls` (`ls /mnt/nfs/guinea.pig`)
> Если файл появился - РАДУЙТЕСЬ.
> Если не появился - Молитесь Альтушке и проверяйте конфиги.

Чипи-Чипи Чапа-Чапа Руби-Руби Лаба-Лаба!!!!!

# Task 4. ЧРОНИ, Синхронизируем времяяяяя
---

Одна из самых приятных частей...

## ISP
```bash
vim /etc/chrony.conf
	local stratum 5
	allow 172.16.1.0/28
	allow 172.16.2.0/28
	# --- Остальные пункты УДАЛИТЬ ---

systemctl enable –-now chronyd
```

## HQ-SRV, HQ-SRV, BR-RTR, BR-SRV, HQ-CLI
```bash
nano /etc/chrony.conf
	server 172.16.1.1 iburst prefer
	#   IP ^^^^^^^^^^ Меняем на свой, тот что 
	# показывает на ISP, на устройстве 
	# который настраиваем
	# --- Остальные пункты УДАЛИТЬ ---
```

```bash
systemctl enable --now chronyd
chronyc sources
```

> Иногда chronyd может быть уже запущен, по этому если в `chronyc sources` вы видите не тот IP, можно попробовать выполнить `systemctl restart chronyd`

> На BR-RTR и HQ-RTR может выдаваться `_gateway`, это нормально и не является ошибкой. Т.к. 172.16.2.1 и 172.16.1.1 соответственно для них являются шлюзами. 

Ну на этом приятная часть заканчивается...

# TASK 5. Настраиваем Ansible (SSH, SSH, и ещё раз SSH)

## BR-SRV
> Проверьте установлен ли Ansible, если его нет (команда `ansible` не найдена) то установите его.
> `apt-get install -y ansible`

Сначала делаем для root
```bash
ssh-keygen -t rsa
	Enter (x3)
```

И тоже самое под sshuser с последующей загрузкой ключей по SSH
```bash
su - sshuser

ssh-keygen -t rsa
	Enter (x3)
	
# ВСЕ IP МЕНЯЙТЕ НА СВОИ!
# vvv HQ-SRV vvv
ssh-copy-id -p 2026 sshuser@192.168.0.2
# vvv HQ-CLI vvv
ssh-copy-id user@192.168.1.10
# vvv HQ-RTR vvv
ssh-copy-id net_admin@172.16.1.2
# vvv BR-RTR vvv
ssh-copy-id net_admin@172.16.2.2
```

> Если у вас вдруг вылезет ошибка то можно попробовать на устройстве, к которому вы пытаетесь подключится, включить sshd. (например на роутерах и на клиенте)
> `systemctl enable --now sshd`

Затем выходим из под sshuser и создаем инвентарь ansible.

```bash
exit
nano /etc/ansible/inv
```
```python
[hq]
192.168.0.2 ansible_port=2026 ansible_user=sshuser
192.168.1.10 ansible_user=user
172.16.1.2 ansible_user=net_admin

[br]
192.168.3.1 ansible_user=net_admin
```

> IP меняйте на свои, тут порядок такой: HQ-SRV, HQ-CLI, HQ-RTR, BR-RTR

Теперь необходимо отключить предупреждение о петухоне
```shell
nano /etc/ansible/ansible.cfg
	[defaults]
	interpreter_python=auto_silent
```

Затем запускаем процесс от пользователя sshuser.
```shell
su - sshuser
ansible all -i /etc/ansible/inv -m ping
```

# TASK 6. Ох... Docker...

## BR-SRV
Видимо на демо экзамене орги решили выпендриться и сделать установку image через iso файл.
Из плюсов, они оставили readme.txt с подсказкой для настройки `env` параметров.

Первым делом включаем докер и даем доступ к нему для sshuser и root'.
```bash
systemctl enable --now docker
usermod -aG docker sshuser
usermod -aG docker root
```
> Если докер не стоит, то ставим его: 
> `apt-get install -y docker-engine docker-compose-v2 `

Дальше ищем и подключаем диск с Additional.iso (он весит `918.7M` и имеет тип `rom`)
```bash
lsblk
mount /dev/sr0 /mnt/
ls /mnt/docker
# Смотрим на то, какие файлы там есть
docker load < /mnt/docker/mariadb_latest.tar
docker load < /mnt/docker/site_latest.tar
nano /mnt/docker/readme.txt
# Смотрим на подсказку, а конкретно на "Переменные для запуска"
```

Дальше пишем yaml файл
```bash
nano web.yaml
```
```yaml
services:
	database:
		container_name: db
		image: mariadb
		restart: always
		environment:
			MARIADB_DATABASE: 'testdb'
			MARIADB_USER: 'test'
			MARIADB_PASSWORD: 'P@ssw0rd'
			MARIADB_ROOT_PASSWORD: 'P@ssw0rd'
		volumes:
			- mariadb:/var/lib/mysql
			  
	app:
		container_name: 'testapp'
		image: 'site'
		restart: always
		ports:
			- "8080:8000"
		environment:
			DB_HOST: "db"
			DB_PORT: "3306"
			DB_TYPE: "maria"
			DB_NAME: "testdb"
			DB_USER: "test"
			DB_PASS: "P@ssw0rd"
volumes:
	mariadb:
```

Ну а теперь можно всё поднимать и радоваться жизни:
```bash
docker compose -f web.yaml up -d
```

Проверить работоспособность можно с HQ-CLI, подключившись по порту `8080`.
Например: http://192.168.3.2:8080 (мой IP для BR-RTR)

# Task 7. Запускаем мудика на HQ-SRV
---
## HQ-SRV

Для начала запустим марию и выполним первичную конфигурацию 
```bash
systemctl enable --now mariadb
mysql_secure_installation
	Enter
	y
	y
	P@ssw0rd
	P@ssw0rd
	y
	y
	y
	y
```

> И как обычно, если `mariadb` не найдена, то устанавливаем её 
> `apt-get install -y mariadb` 

Затем снова монтируем Additional.iso и устанавливаем сайт
```bash
mount /dev/sr0 /mnt

cp /mnt/web/index.php /var/www/html
cp /mnt/web/logo.png /var/www/html

nano /var/www/html/index.php
```
```php
<?php
$servername = "localhost"
$username = "webc"
$password = "P@ssw0rd"
$dbname = "webdb_"
```
```bash
rm -f /var/www/html/index.html
```

Теперь переходим к базе данных
```bash
mariadb -u root -p
	P@ssw0rd
```
```SQL
CREATE DATABASE webdb;
CREATE USER 'webc'@'localhost' IDENTIFIED BY 'P@ssw0rd';
GRANT ALL PRIVILEGES ON webdb.* TO 'webc'@'localhost' WITH GRANT OPTION;
EXIT;
```

Теперь необходимо импортировать базу данных с Additional.iso, но перед этим нужно исправить кодировку.
```bash
iconv -f utf-16le utf-8 /mnt/web/dump.sql > dump.sql
mariadb -u root -p webdb < dump.sql
	P@ssw0rd
```

Затем запускаем веб сервер
```
systemctl enable --now httpd2
```

> Если сервис не найден, то его нужно установить: `apt-get install -y apache2`

# TASK 8. Статическая трансляция портов
---
## HQ-RTR

Очень простая часть, просто нужно изменить **nftables**.
```bash
vim /etc/nftables/nftables.nft
```
```yaml
table inet nat {
	chain postrouting {
		type nat hook postrouting priority srcnat;
		oifname "ens19" masquerade
	}
	chain prerouting {
		type nat hook prerouting priority filter;
		ip daddr 172.16.1.2 tcp dport 8080 dnat ip to 192.168.0.2:80
		ip daddr 172.16.1.2 tcp dport 2026 dnat ip to 192.168.0.2:2026
	}
}
```

> Не забудьте поменять 192.168.0.2 на IP адрес вашего HQ-SRV

## BR-RTR

```bash
vim /etc/nftables/nftables.nft
```
```yaml
table inet nat {
	chain postrouting {
		type nat hook postrouting priority srcnat;
		oifname "ens19" masquerade
	}
	chain prerouting {
		type nat hook prerouting priority filter;
		ip daddr 172.16.2.2 tcp dport 8080 dnat ip to 192.168.3.2:8080
		ip daddr 172.16.2.2 tcp dport 2026 dnat ip to 192.168.3.2:2026
	}
}
```

> Не забудьте поменять 192.168.3.2 на IP адрес вашего BR-SRV

# TASK 9. Nginx - Финальный финал ваших страданий
---
# ISP

```bash
nano /etc/nginx/sites-available/reverse.conf
```
```nginx
server {
	server_name web.au-team.irpo;
	location / {
		proxy_pass http://172.16.1.1:8080;
		proxy_set_header Host $host;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto $scheme;
	}
}
server {
	server_name docker.au-team.irpo;
	location / {
		proxy_pass http://172.16.2.1:8080;
		proxy_set_header Host $host;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X-Frowarded-Proto $scheme;
	}
}
```
```bash
ln -s /etc/nginx/sites-available/reverse.conf /etc/nginx/sites-enabled/
systemctl enable --now nginx
```

> Если папка nginx или сервис nginx не найдены - ставим nginx.
> `apt-get install -y nginx`

# TASK 10. Nginx - Авторизация через nginx
---
## ISP

Не сделал пункт 9? 
ИДИ ДЕЛАТЬ ПУНКТ 9!!!

```bash
htpasswd -c /etc/nginx/.htpasswd WEB
	P@ssw0rd
	P@ssw0rd
```

> Выдаёт ошибку? Не беда, пиши `apt-get install -y apache2-htpasswd`
> И похуй что там написано Apache. ЭТА СУКА РАБКА, ОНА И NGINX ГОТОВА ЕБАТЬ.

И добавляем 
	auth_basic "Restricted area";
	auth_basic_user_file /etc/nginx/.htpasswd;

```bash
nano /etc/nginx/sites-available/reverse.conf
```
```nginx
server {
	server_name web.au-team.irpo;
	location / {
		proxy_pass http://172.16.1.1:8080;
		proxy_set_header Host $host;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto $scheme;
		auth_basic "Restricted area";
		auth_basic_user_file /etc/nginx/.htpasswd;
	}
}
```

И с стоном перезапускаем Nginx
```shell
systemctl restart nginx
```
Можно проверить на HQ-CLI написав в браузер `http://web.au-team.irpo`

# TASK 11. Yabluat Browser
---
## HQ-CLI

Ставим всратый никому не нужен Яблять Браузер.
```bash
su -
apt-get update
apt-get install -y yandex-browser
```

Потом в меню находим этот Яблоко Браузер и через ПКМ добавляем на рабочий стол.

# ГОТОВО! МОДУЛЬ ВЫПОЛНЕН!
## Вам разрешается выйти из кабинета и проблеваться как следует :)
