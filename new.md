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
mdadm --create --verbose /dev/md0 -l 0 -n 2 /dev/sdb1 /dev/sdcc1
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

# TASK 4. Настраиваем Ansible (SSH, SSH, и ещё раз SSH)

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

# TASK 5. Ох... Docker...

## BR-SRV
Видимо на демо экзамене орги решили выпендриться и сделать установку image через iso файл.
Из плюсов, они оставили readme.txt с подсказкой для настройки `env` параметров.

Первым делом включаем докер и даем доступ к нему для sshuser.
```bash
systemctl enable --now docker
usermod -aG docker sshuser
```
> Если докер не стоит, то ставим его: 
> `apt-get install -y docker-engine docker-compose-v2 `

