# ДЕМО Экзамен

# Новые IP адреса


---


:::warning
На экзамене их могут снова сменить, по этому проверяйте их непосредственно на экзамене

:::


:::warning
В методичке указаны старые IP адреса, по этому проверяйте всё перед изменением файла или отправке команды


В таблице ниже, в круглых скобочках, указаны старые IP адреса, чтобы было немного проще ореинтироваться  

## **ОРЕИНТИРУЙТЕСЬ ПО НОМЕР МАСКИ И НАЗВАНИЮ УСТРОЙСТВА В ТЕКСТЕ**

:::

| **HQ_RTR:** |    | (172.16.4.1/28) |
|----|----|----|
|     172.16.4.1/28 | ISP |    |
|     192.168.0.62/26 | HQ_SRV |    |
|     10.5.5.1/30 | Туннель с BR_RTR |    |
|     192.168.0.78 | HQ_CLI |    |
| 
--- | 
--- | 
--- |
| **HQ_SRV:** | 192.168.0.1/26 | (192.168.0.1/26) |
| **HQ_CLI:** | 192.168.0.68/28 | (192.168.0.65/27)  |
| 
--- | 
--- | 
--- |
| **BR_RTR:** |    | (172.16.5.1/28)  |
|     10.5.5.2/30 | Туннель с HQ_RTR |    |
|     172.16.5.1/28 | ISP |    |
|     192.168.1.30/27 | BR_SRV |    |
| 
--- | 
--- | 
--- |
| **BR_SRV:** | 192.168.1.1/27 | (192.168.3.1/27) |
| 
--- | 
--- | 
--- |
| **ISP:** |    |    |
| 172.16.4.14/28 | HQ |    |
| 172.16.5.14/28 | BR |    |


\
# Открытие методички в консоли сервера/клиента/роутера


---

Так как открывать данную страницу в браузере слишком "палевно", 

предусмотрен вариант с открытием непосредственно в терминале.


## Подготовка Proxmox


---

Для наиболее эффективной работы, вы можете открыть терминал в отдельном окне.

Для этого дважды нажмите на нужную виртуальную машину в Proxmox.

На скриншоте я дважды нажал на `101 (edu-docker)` и у меня открылась его консоль в новом окне.

 ![](attachments/7af2e4c0-00b6-4ec2-9de8-d539e57c2fb9.png " =634x506.5")

Это очень удобно когда вы настраиваете несколько машин.


## Скачивание и открытие файла с методичкой


---

Для того чтобы открыть файл с методичкой, вам необходимо написать следующую команду:

```bash
wget -O test.md https://mirea.dsvinka.ru && nano test.md
```

 ![](attachments/e590850e-a5b4-459f-ac5b-8cba47a9d6af.png " =390x259.5")

У данного способа есть только один недостаток, символы которые отвечают за отображение (`` ` `` , `:`, ```` ``` ````, `>`, `![]()`) 

Учитывайте это когда будете чистать текст или переписывать команды.

Считайте что ```` ``` ```` это блок с командой, а `` ` `` это кавычки.


\

---


---


---


\
# 1. Настройте доменный контроллер Samba на машине BR-SRV.

## Настраиваем Samba


---

Удаляем `smb.conf` и другие конфигурационные файлы и создаём папку:

```shell
rf -f /etc/samba/smb.conf
rm -rf /var/lib/samba
rm -rf /var/cache/samba
mkdir -p /var/lib/samba/sysvol
```

Запускаем автоматическую настройку

```shell
samba-tool domain provision --use-rfc2307 --interactive
```

Задаем все параметры по умолчанию кроме:

* DNS Backend: `NONE` (на скриншоте неверно)
* Administrator password: `P@ssw0rd`
* Retype password: `P@ssw0rd`

После успешной настройки покажет параметры домена. 

 ![](attachments/b1b86d2e-9493-4946-bac8-c9ed4e3fd357.png)  ![](attachments/187d2654-1c8b-47f4-8f0b-dd3d4d4c6d06.png)

Заходим в smb.conf и добавляем один параметр в самый конец первого заголовка:

```bash
nano /etc/samba/smb.conf
```

```ini
dns forwarder = 192.168.0.1
```


:::tip
192\.168.0.1 - HQ_SRV

:::

Запускаем samba и bind с добавлением в автозагрузку.

```shell
systemctl enable --now samba
systemctl enable --now bind
```

Прописываем команду:

```bash
Cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
```


## Настраиваем группу и пользователя


---

Cоздаем группу для пользователей домена:

```shell
samba-tool group add hq
```

Cоздаем пользователей:

```shell
samba-tool user create user1.hq "P@ssw0rd" --home-directory=/home/AU-TEAM/user1.hq --uid=user1.hq
```

Добавляем пользователя в группу

```bash
samba-tool group addmembers hq user1.hq
samba-tool group addmembers hq user2.hq
samba-tool group addmembers "Account Operators" hq
samba-tool group addmembers "Allowed RODC Password Replication Group" hq
```

 ![](attachments/65337250-e0ad-4540-a742-e25702be562c.png)

Перезагружаем samba

```bash
systemctl restart samba
```


:::warning
**Перезагружаем сервер!!!**

```bash
reboot
```

:::


## Вводим в домен hq-cli


---

Открываем терминал, через `CTRL+ALT+T`, или меню в левом нижнем углу экрана.

Проверяем настройку в `resolv.conf`

```pro
su -
nano /etc/resolv.conf
```

Проверяем что адрес DNS сервера настроен на Samba AD:

```properties
search au-team.irpo
nameserver 192.168.0.1
```


:::tip
192\.168.0.1 - HQ_SRV

:::


Сохраняем `CTRL + O` и закрываем редактирование файла  `CTRL + X`

Если в файле были сделаны изменения, то перезагрузите систему

```bash
reboot
```

Далее вводим устройство в домен:

```bash
Realm join -U user1.hq au-team.irpo
```


:::info
Запятые в команде - это не ошибка

`-U` - **ОБЯЗАТЕЛЬНО** с заглавной буквы.

:::


## Настройка политики повышения привилегий (через sudo):


---

Открываем терминал, входим на HQ-CLI под рутом и через команду Echo вписываем параметры в `/etc/sudoers.d/hq`:

```shell
su -
Echo "%hq ALL=(ALL) NOPASSWD:/bin/cat,/bin/grep,/usr/bin/id" > /etc/sudoers.d/hq
```

### Импорт пользователей на сервере BR-SRV:

Создайте скрипт для импорта:

```shell
nano /opt/import_users.sh
```

Пишем

```shell
#!/bin/bash
CSV_FILE="/opt/users.csv"
 while IFS=, read -r username password group; do
  # Создание пользователя
     samba-tool user create "$username" "$password" --home-directory="/home/$username" --uid="$username"
      # Добавление в группу
     samba-tool group addmembers "$group" "$username"
done < "$CSV_FILE" 
```

 ![](attachments/712f1086-9361-4de0-950e-360b3537ad87.png)

Сделайте скрипт исполняемым:

```shell
chmod +x /opt/import_users.sh
```

Запустите его:

```shell
/opt/import_users.sh
```


# 2. Сконфигурируйте файловое хранилище:


---

Выводим список подключенных дисков и их имена.

```shell
lsblk
```

 ![](attachments/acb124e3-666c-44b1-b455-6f9b66f2f2ff.png)

## Создание таблицы разделов


---

Для разбиения диска, запускаем fdisk с именем устройства:

```shell
fdisk /dev/sdb
```

Последовательно выполняем команды: Вводим `g` чтобы создать новую пустую таблицу разделов:

```shell
Command (m for help): g
```

Вводим команду `n` чтобы создать новый раздел:

```shell
Command (m for help): n
```

Будет предложено ввести номер раздела.

* Жмем «Enter», чтобы использовать значение по умолчанию (1)

Далее необходимо указать первый сектор.

* Жмем «Enter», чтобы использовать значение по умолчанию.

При следующем запросе необходимо ввести последний сектор.

* Жмем «Enter», так как используем весь диск

 ![](attachments/e971fd2f-340b-4025-9935-1b036cfe8f33.png)

Сохраняем изменения, запустив команду `w`

```shell
Command (m for help): w
```

Команда запишет таблицу на диск и выйдет из меню `fdisk`.Ядро прочитает таблицу разделов устройства без перезагрузки системы.Аналогично создаем разделы на других дисках `/dev/sdc`, `/dev/sdd`

 ![](attachments/8cc96668-9b4b-4e6c-9fdf-2bed23b03236.png)

## Создание программного RAID5

Для сборки массива применяем следующую команду:

```shell
mdadm --create --verbose /dev/md0 -l 5 -n 3 /dev/sdb1 /dev/sdc1 /dev/sdd1
```

Система задаст контрольный вопрос, хотим ли мы продолжить и создать RAID — нужно ответить `y`: Мы должны увидеть что-то на подобии: 

 ![](attachments/5aac417f-0d84-4960-93d9-1c53412f6c5a.png)

Посмотреть состояние всех RAID можно командой:

```shell
cat /proc/mdstat
```

 ![](attachments/518f6e52-8bb0-4b57-952f-73df5fc0c94a.png)

## Монтирование файловой системы массива

Отформатируем разделы в ext4:

```shell
mkfs.ext4 /dev/md0
```

 ![](attachments/fcf02882-f9f8-486b-be68-563e93031636.png)

В корне системы создадим директорию /raid5

```shell
mkdir /raid5
```

Примотируем к RAID директорию /raid5 командой:

```shell
mount /dev/md0 /raid5
```

Чтобы разделы монтировались при загрузке системы Открываем fstab:

```shell
nano /etc/fstab
```

И добавляем строки

```shell
/dev/md0    /raid5    ext4    defaults    0    0
```

 ![](attachments/7e1d71be-15bb-4cf9-a66b-2c93c9d74bc7.png)

Проверяем примонтированные разделы:

```shell
df -h
```


## Сервер NFS

Создаем папку общего доступа `/raid5/nfs`

```shell
mkdir /raid5/nfs
```

Запускаем NFS сервер:

```shell
systemctl enable -- now nfs
```

Открываем на редактирование файл `/etc/exports` который содержит информацию о каталогах, экспортируемых с сервера:

```shell
nano /etc/exports
```

Создаем шару из каталога `/raid5/nfs`, которая будет доступна для всех узлов сети `192.168.0.64/27` Добавим в него строку:

```shell
/raid5/nfs 192.168.0.64/27(rw,subtree_check)
```

Выполняем экспорт данных (перечитаем конфигурационный файл /etc/exports, чтобы сервер начал отдавать настроенные шары):

```shell
exportfs -a
```

### Автомонтирование

На HQ-CLI устанавливаем компонент для клиентской части NFS: Создаем директорию для автомонтирования `/mnt/nfs`

```shell
mkdir /mnt/nfs
```

Пробуем примонтировать шару:

```shell
mount -t nfs 192.168.0.1:/raid5/nfs /mnt/nfs
```

Для автоматического монтирования на HQ-CLI после перезагрузки, используем `fstab`. Открываем файл `fstab`:

```shell
nano /etc/fstab
```

И добавляем строку:

```shell
192.168.0.1:/raid5/nfs        /mnt/nfs    nfs     auto    0 0
```

 ![](attachments/f5422c9f-76f6-40fc-a8f5-0b111ac1310c.png)


:::tip
192\.168.0.1 - HQ_SRV

:::

# 3. Настройте синхронизацию времени между сетевыми устройствами по протоколу NTP

## Настройка NTP сервера на HQ-RTR


---

Заходим в конфигурационный файл `chrony.conf`

```shell
nano /etc/chrony.conf
```

Приводим конфигурационный файл к следующему виду IP-адреса согласно вашим параметрам, остальные пункты комментировать или удалить!:

```toml
server 127.0.0.1 iburst prefer
local stratum 5
allow 192.168.0.0/26
allow 192.168.0.64/27
allow 192.168.1.0/27
allow 10.5.5.0/30
```

 ![](attachments/fe627f6f-a5e2-40a2-bef3-317794be7523.png)


:::tip
Тут указываются именно IP подсетей, а не конкретно устройств.

В примере подсети стоят такие:

HQ_SRV, HQ_CLI, BR_SRV, BR_RTR


Cмотрите по заданию на каком именно устройстве должен стоять Chrony сервер.

**В примере указан что сервер стоит на HQ-RTR**


На скриншоте адреса указаны неверно!

:::


Сохраняем файл и выходим. Запускаем службу синхронизации

```shell
systemctl enable --now chronyd
```

 ![](attachments/f21aad83-3b5b-4764-ae09-597924f9bb5d.png)

## Настройка NTP клиентов на примере HQ-SRV


---

Заходим в конфигурационный файл "chrony.conf"

```shell
nano /etc/chrony.conf
```

Приводим конфигурационный файл к следующему виду IP-адреса согласно вашим параметрам.

Остальные пункты комментировать или удалить!:

```toml
server 192.168.0.62 iburst prefer
```


:::tip
192\.168.0.62 - Замените на IP адрес вашего Chrony сервера, исходя из условий задания и устройства.

Напоминаю что эта настройка это для HQ-SRV.

:::


Сохраняем файл и выходим.Запускаем службу синхронизации:

```shell
systemctl enable --now chronyd
```

 ![](attachments/be9cd7f1-0d82-45b9-baa1-aa4e17a7e311.png)

Проверяем:

```shell
chronyc sources
```

 ![](attachments/cebab6bf-4e11-4ba1-8d8c-291a849c30f6.png)

Остальные устройства настраиваем по аналогии.

# 4. Сконфигурируйте ansible на сервере BR-SRV

## Создание пары SSH-ключей. 


---

Чтобы заходить на удаленные машины, пользователь на BR-SRV (`sshuser` и `root`) должен создать пару из закрытого/открытого RSA ключа. Это делается следующей командой:

```shell
ssh-keygen -t rsa
```

 ![](attachments/e69980b1-2dd7-4977-a3f1-f7e36b63fb29.png)

В результате в каталоге `/home/sshuser/.ssh` или `/root/.ssh` будут созданы файлы ключей:

```shell
ls -l ~/.ssh

  id_rsa  # закрытый ключ
  id_rsa.pub # открытый ключ
```

Заходим под пользователем `sshuser` и `root` (выполняется аналогично)

```shell
su - sshuser
```

Копируем открытый SSH-ключ на удаленные устройства под пользователем `sshuser`: Копируем ключ для пользователя `sshuser` на HQ-SRV 

На HQ-SRV ssh порт изменен, указываем его

```shell
ssh-copy-id -p 2024 sshuser@192.168.0.1
```

 ![](attachments/a3e7afec-6d1c-4efb-b9bd-85d14394401d.png)

Копируем ключ для пользователя user на HQ-CLI

```shell
ssh-copy-id user@192.168.0.65
```

Копируем ключ для пользователя net_admin на HQ-RTR

```shell
ssh-copy-id net_admin@172.16.4.1
```

Копируем ключ для пользователя net_admin на BR-RTR

```shell
ssh-copy-id net_admin@172.16.5.1
```


:::tip
Очень внимательно с IP адресами, их на экзамене могут сменить!

:::

## Подготовка файла инвентаря (hosts) 

Создаем файл инвентаря `/etc/ansible/inv`

```shell
nano /etc/ansible/inv
```

Сначала указывается название группы в квадратных скобках, затем перечисляются хосты.Имена хостов прописываются в виде IP.После названия хоста можно указать параметры подключения к хосту в одну строку.

 ![](attachments/843e3363-fd37-4879-abfd-e29cbe8ffa10.png)


:::tip
**Yablochko076:**

> Малая правка ансибла:
>
> У `net_admin` адрес лучше писать `10.5.5.1` и `10.5.5.2`, прикопаться могут

:::

Запуск команд с пользовательским инвентарем

```shell
ansible all -i /etc/ansible/inv -m ping
```

Может появиться предупреждение про обнаружение интерпретатора Python, на целевом хосте 

 ![](attachments/469e99f9-b917-44ec-ba42-8739347d4544.png)

Для управления поведением обнаружения в глобальном масштабе необходимо в файле конфигурации Ansible `/etc/ansible/ansible.cfg`

В разделе `[defaults]` прописать ключ `interpreter_python` с параметром `auto_silent`.

В большинстве дистрибутивов прописываем вручную:

```shell
nano /etc/ansible/ansible.cfg
```

```ini
[defaults]
interpreter_python=auto_silent
```

 ![](attachments/adc14c0e-1ba0-45d6-ad94-7150d8ffcb44.png)

Проверяем

```shell
ansible all -i /etc/ansible/inv -m ping
```

 ![](attachments/7e559a42-05aa-4278-8da9-2b02ab392184.png)

# 5. Развертывание приложений в Docker на сервере BR-SRV.


---

Запустить сервис контейнеризации docker и добавить его в автозагрузку:

```shell
systemctl enable --now docker 
```


## Меняем порт веб интерфейса ЦУС сервера


---

Перед настройкой wiki необходимо сменить порт веб интерфейса ЦУС сервера! 

На HQ-CLI открываем браузер в водим адрес https://192.168.1.1 вводим пароль от `root` и заходим в ЦУС


:::tip
192\.168.1.1 - BR-SRV

:::

 ![](attachments/c60d5cff-3990-4234-a1e4-282b33b0e15c.png)

Нажимаем настройка

 ![](attachments/d11e27c3-a265-4fbf-b162-506bac686dbd.png)

Выбираем режим эксперта, применить

 ![](attachments/0bd96db7-b275-4fc1-850e-c9412ecbfa8f.png)

В меню выбираем веб-интерфейс.

 ![](attachments/06fc68a9-7314-487b-a679-e5721e6e78a5.png)

Меняем порт на 8081.

 ![](attachments/26eb086a-7e70-4512-887d-d783b277552a.png)

Нажимаем применить и перезапустить http-сервер.

## Установка MediaWiki


---

Для упрощения создания `wiki.yml` в поисковой системе на HQ-CLI пишем `mediawiki docker-compose`

 ![](attachments/c615316f-31a3-4a81-863e-fb97b0e452cc.png)

Переходим по ссылке.На странице находим раздел "Adding a Database Server" нажимаем

 ![](attachments/8f224e97-f175-4cd5-9e2c-a843ea8ce1e2.png)

Выделяем код и копируем его

 ![](attachments/8d418c62-b6b9-4ea7-879b-7ddaed78fa5e.png)

Подключаемся по SSH к BR-SRV с HQ-CLI.

```shell
ssh sshuser@192.168.1.1 -p 2024
```

 ![](attachments/c4e643d5-332c-4523-bac4-1863c0bc3a27.png) 

заходим под root

```shell
su -
```

Создаем файл

```shell
nano ~/wiki.yml
```

Вносим изменения в файл:

> Порт: `8080`
>
> Имя второго контейнера и его образа: `mariadb`
>
> Имя БД: `mediawiki`
>
> Пользователь БД: `wiki` / `WikiP@ssw0rd`
>
> Изменяем параметр volumes **у контейнера mariadb**: `dbvolume:/var/lib/mariadb`

```yml
services:
  wiki:
    image: mediawiki
    restart: always
    ports:
      - 8080:80
    links:
      - database
    volumes:
      - images:/var/www/html/images
      # - ./LocalSettings.php:/var/www/html/LocalSettings.php
  mariadb:
    image: mariadb
    restart: always
    environment:
      MYSQL_DATABASE: mediawiki
      MYSQL_USER: wiki
      MYSQL_PASSWORD: WikiP@ssw0rd
      MYSQL_RANDOM_ROOT_PASSWORD: 'yes'
    volumes:
      - dbvolume:/var/lib/mariadb

volumes:
  dbvolume:
    external: true
  images:
```

 ![](attachments/2d7b6302-114e-41a2-82f5-02f62de4fd30.png)

Чтобы отдельный volume для хранения базы данных имел правильное имя - создаём его средствами docker:

```shell
docker volume create dbvolume
```


:::tip
Посмотреть все имеющиеся volume можно командой `docker volume ls`

:::

Выполняем запуск стека контейнеров с приложением MediaWiki и базой данных описанных в файле wiki.yml:

```shell
docker compose -f wiki.yml up -d
```

Ждем завершения установки и запуска

  ![](attachments/e12d2754-d7a2-427c-8670-a8d604f1f60b.png)

Открываем браузер по адресу нашего сервера http://192.168.1.1:8080

Нажимаем `"set up the wiki"`, приступаем к установке.

 ![](attachments/4555b9ba-81ca-41cc-bac9-679687272377.png)

Выбираем русский язык, далее

 ![](attachments/440df588-15c7-4ff9-89c1-bddc296aa90f.png)

В следующем пункте проверка прошла нажимаем далее

 ![](attachments/12fcb5ff-ef06-4c42-a575-33b56f92ab0b.png)

Настраиваем параметры базы данных:

> Хост: `mariadb`
>
> Идентификатор: `mediawiki`
>
> Учетная запись: `wiki` / `WikiP@ssw0rd`


Далее

 ![](attachments/db2c101c-b2d7-468a-af07-110e22c12f26.png)

Подтверждаем, далее

 ![](attachments/bdefb8ea-9c66-4e87-83e9-a6c097dc6cf3.png)

Задаем параметры

> Название — `DemoWiki`
>
> Учетная запись — `wiki` / `WikiP@ssw0rd`
>
> Адрес — `wiki@au-team.irpo`

Выбираем пункт `"хватит уже, просто установить"`

Далее

 ![](attachments/baf7d24b-82bf-48f7-8246-aa9c08109e45.png)

Нажимаем далее

 ![](attachments/3d93c177-9daf-4f42-97be-73b1d92712d3.png)


Далее

 ![](attachments/16df8a0f-39ee-46c7-8f37-d4dbf8a2ce77.png)

Автоматически скачается `LocalSettings.php`

 ![](attachments/a9e365cf-565a-4c40-8c90-c3f76b66d6e7.png)

Необходимо передать файл `LocalSettings.php` с HQ-CLI на BR-SRV:

```shell
scp user@192.168.1.1:~/Загрузки/LocalSettings.php ./
```

Раскомментируем строку в файле wiki.yml:

```shell
nano wiki.yml
```

```yml
volumes:
  - ./LocalSettings.php:/var/www/html/LocalSettings.php
```

 ![](attachments/d63ba5ec-afc0-4a52-a6f0-489a5f091f35.png)

Перезапускаем сервисы средствами docker-compose:

```shell
docker compose -f wiki.yml stop
```

```shell
docker compose -f wiki.yml up -d
```

 ![](attachments/c602eb79-ccfb-420f-a5ef-30ee24031ab0.png)

Проверяем доступ к Wiki: http://192.168.1.1:8080 

 ![](attachments/9fa82bab-f62a-4686-ad9f-a23572a187f9.png)

# 6. На маршрутизаторах сконфигурируйте статическую трансляцию портов

## **BR-RTR**


---

На **BR-RTR** изменяем правило переадресации в таблице `table inet nat`, добавляя `chain prerouting`:

```bash
nano /etc/nftables/nftables.nft
```

```bash
chain prerouting {
	type nat hook prerouting priority filter; 
   	ip daddr 172.16.5.1 tcp dport 80 dnat ip to 192.168.1.1:8080
	ip daddr 172.16.5.1 tcp dport 22 dnat ip to 192.168.1.1:2222
}
```

 ![](attachments/50747853-f9bf-453c-a0cd-1cf67fa31b2e.png)


:::tip
По традиции на скриншоте неверные IP адреса, по этому смотрите блок с кодом над ним.

Это также касается настройки HQ-RTR.


172\.16.5.1 - BR_RTR

192\.168.1.1 - BR_SRV


Важно отметить что тут IP 172.16.5.1 (ISP интерфейс) а не 10.5.5.x (туннель).

Так как иначе бы к сайту смогли бы подключиться только устройства локальной сети.

А указывая 172.16.5.1, мы допускаем переадресацию портов для запросов, которые идут из вне (из глобальной сети)

:::


Перезапускаем `nftables`!

```bash
systemctl restart nftables
```


## HQ-RTR


---

На **HQ-RTR** изменяем правило переадресации в таблице `table inet nat`, добавляя `chain prerouting`:

```bash
nano /etc/nftables/nftables.nft
```

```bash
chain prerouting {
  type nat hook prerouting priority filter; 
  ip daddr 172.16.4.1 tcp dport 22 dnat ip to 192.168.1.1:2222
}
```

 ![](attachments/44636d46-adfc-45af-a155-519b544719a0.png)

Перезапускаем `nftables`!

```shell
systemctl restart nftables
```


\

# 7. Запустите сервис Moodle на сервере HQ-SRV


---

Запускаем веб-сервер и добавляем в автозагрузку:

```shell
systemctl enable --now httpd2
```

Включаем и добавляем в автозагрузку MySQL:

```shell
systemctl enable --now mariadb
```

## Подключаемся к MySQL, создаём базу данных и пользователя:


---

> * Имя базы данных: `moodledb`
> * Имя пользователя: `moodle`
> * Пароль: `P@ssw0rd`

Подключаем модуль `mysql_secure_installation` (tab на этом пункте работает)

* Первый пункт: `Enter`
* Второй пункт: `y`
* Третий пункт: `n`
* Все остальные пункты: `y`

 ![](attachments/04103f72-cc41-49b9-af25-105ca32e54eb.png)

Далее пишем команду:

```shell
mysql -u root -p
```

Вводим пароль от root. 

 ![](attachments/bfa3522f-8fb1-4c0c-87c2-9c8f956bdb8b.png)

Создаем базу (можно писать все в нижнем регистре (маленькими буквами)):

```sql
CREATE DATABASE moodledb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'moodle'@'localhost' IDENTIFIED BY 'P@ssw0rd';
GRANT ALL PRIVILEGES ON moodledb.* TO 'moodle'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

 ![](attachments/c66397f0-2e31-40fd-9894-72bdaaec0241.png)

Загружаем код проекта Moodle:

```shell
git clone git://git.moodle.org/moodle.git
```

 ![](attachments/f4121c70-bca1-49a8-8370-4a82c618171e.png)

Переходим в загруженный каталог moodle:

```shell
cd moodle
```

Извлекаем список каждой доступной ветви:

```shell
git branch -a
```

 ![](attachments/139b9d61-55fe-4b64-ab3d-0e1647f758b4.png)

Сообщаем git, какую ветку отслеживать или использовать:

```shell
git branch --track MOODLE_405_STABLE origin/MOODLE_405_STABLE
```

Переключаемся на ветку с нужной версией:

```shell
git checkout MOODLE_405_STABLE
```

 ![](attachments/424dd431-348c-4917-9269-f597518c8fea.png)

Возвращаемся в корневой каталог:

```shell
cd
```

Копируем локальный репозиторий в `/var/www/html/`:

```shell
cp -R moodle /var/www/html/
```

Создаём необходимую структуру каталогов для корректной установки и работы Moodle:

```shell
mkdir /var/moodledata
```

Назначаем права:

```shell
chmod 777 /var/moodledata
chown -R apache2:apache2  /var/www/html/moodle
chmod -R 755 /var/www/html/moodle
```

Создаем и редактируем конфигурационный файл для веб-сервера Apache:

```shell
nano /etc/httpd2/conf/sites-available/moodle.conf
```

```markup
<VirtualHost *:80>
  ServerName au-team.irpo
  ServerAlias moodle.au-team.irpo
  DocumentRoot /var/www/html/moodle
  <Directory "var/www/html/moodle">
    AllowOverride ALL
    Options =Indexes FollowSymLinks
  </Directory>
</VirtualHost>
```

 ![](attachments/e516223a-d8cd-4435-abd1-d61494ef16af.png)

Создаём символьную ссылку из `sites-available` на `sites-enabled`:

```shell
ln -s /etc/httpd2/conf/sites-available/moodle.conf /etc/httpd2/conf/sites-enabled/
```

Проверяем синтаксис файла виртуального хоста:

```shell
apachectl configtest
```

 ![](attachments/05c56c15-2b4e-465c-9ed7-e3256b9df3f3.png)

Правим количество входных переменных, которые могут быть приняты в одном запросе. Для работы Moodle - необходимо 5000, а значение в php.ini по умолчанию 1000:

Заходим в конфиг

```shell
nano /etc/php/8.1/apache2-mod_php/php.ini
```

Нажимаем `ctrl + _`набираем № строки `389`, нажимаем EnterНаходим строку `max_input_vars` изменяем значение:

* Убираем точку с запятой в начале строки (`;`) и ставим значение 5000

Сохраняем `CTRL + O` и выходим `CTRL + X`

 ![](attachments/7b1b5f23-7931-4e6d-8012-3ab2e4faef34.png)

Перезапускаем веб-сервер:

```shell
systemctl restart httpd2
```


Переходим на HQ-CLI, открываем браузер пишем домен нашего сайта: http://au-team.irpo

Попадаем на страницу установки Moodle:


:::warning
Если у вас не получается подключиться по доменному имени - не беспокойтесь.

Сначала попробуйте подключиться по IP адресу.

HQ-SRV - http://192.168.0.1


Если и так не сработает - паникуйте 🙂

:::

 ![](attachments/fbec66b9-f631-47fa-ba7c-6d510a81b312.png)

Выбираем язык русский, нажимаем Далее.

Изменяем каталог данных на `/var/moodledata` и подтверждаем пути.

 ![](attachments/7a00de88-48e4-4f4b-991c-3e9b44193d6e.png)

Выбираем тип базы данных mariadb, подтверждаем.

 ![](attachments/55ab8035-25e1-4f1a-9ed8-cbf21b0e47ea.png)

Вносим параметры нашей базы данных, нажимаем Далее

 ![](attachments/535d9d75-4414-478d-9528-8476ead78089.png)

Принимаем лицензию

 ![](attachments/f1f9fa40-b156-448b-9e37-85d965e70266.png)

Проверяем настройки сервера (все ок - зеленое) нажимаем продолжить.

 ![](attachments/de9a8b0b-e6af-46e4-9a48-c6cff387ab60.png)

Ждем окончания установки, нажимаем продолжить.

 ![](attachments/fb70cd6d-d24b-4451-8c3a-24c272a328cf.png)

Делаем первичные настройки (пароль - `P@ssw0rd`, Email - `moodle@au-team.irpo`), нажимаем обновить профиль.

 ![](attachments/4f739a8f-3384-4fb8-a789-b7507bafb680.png)

В наименовании сайта задаем номер рабочего места!!

 ![](attachments/4785608b-acfe-4b3a-b8eb-2c40eec2be43.png)

Нажимаем сохранить изменения.Задаем контакт поддержки, сохраняем.

 ![](attachments/fa56081c-99bf-4b0e-9055-5f385580566b.png)

**Moodle настроен!**

# 8.Настройте веб-сервер Nginx как обратный прокси-сервер на HQ-RTR

**Выключаем встроенный веб сервер альт линукса!!!**

```shell
systemctl disable ahtthd.service
systemctl stop ahtthd.service
```

Запуск и добавление в автозагрузку

```shell
systemctl enable --now nginx
```

Открываем на редактирование конфигурационный файл Nginx

```shell
nano /etc/nginx/nginx.conf
```

Спускаемся в конец HTTP таблицы и перед последней фигурной скобкой `}` прописываем настройки.

```nginx
server {
  listen 80;
  server_name moodle.au-team.irpo;

  location / {
    proxy_pass http://192.168.0.1:80;
  }
}

server {
  listen 80;
  server_name wiki.au-team.irpo;

  location / {
    proxy_pass http://192.168.1.1:8080;
  }
}
```


:::tip
Следите за IP адресами.

192\.168.1.1:80 - Сервер на котором установлен Moodle (HQ-SRV)

192\.168.1.1:8080 - Сервер на котором установлен MediaWiki (BR-SRV)

:::

Перезагружаем Nginx

```shell
systemctl restart nginx
```

 ![](attachments/9e831c72-4482-4fd1-9cb7-6fdc261bf0fa.png)

# 9. Установить яндекс браузер на CLI.

Заходим в терминал под root, обновляем репозитории:

```shell
su -
apt-get update
```

Устанавливаем яндекс браузер:

```shell
apt-get install yandex-browser-stable -y
```

 ![](attachments/1c65bafc-a2a1-4dfc-a5ff-fe1647c675ca.png)

Заходим в `Меню` -> `Все программы` -> `Интернет` -> `Yandex Browser` Нажимаем правой кнопкой мыши -> `"Добавить на рабочий стол"` 

 ![](attachments/b0385468-ef96-4b0b-8ef5-40c45520658c.png)

**Готово!!!**


# БЛАГОДАРНОСТИ

На случай, если данный материал обнаружат служители колледжа КПК МИРЭА и отсутствия в следствии проблем у людей, о которых говориться в этом сегменте, имена были заменены на многим известные никнеймы.



:::tip
**Уважаемый Ramen!**


Хочу выразить Вам искреннюю благодарность за неоценимую помощь в написании методических указаний к демо-экзамену. 

Ваши знания и опыт стали для меня ценным ресурсом, и я очень ценю время и усилия, которые Вы вложили в этот проект.


Ваши рекомендации и конструктивные предложения значительно улучшили качество методических указаний. Благодаря Вашему вниманию к деталям и глубокому пониманию предмета, мы смогли создать документ, который будет полезен как преподавателям, так и студентам. Я особенно признателен за Вашу готовность делиться своими идеями и подходами, что позволило нам рассмотреть различные аспекты организации экзамена и сделать его более прозрачным и доступным.


Ваш профессионализм и преданность делу вдохновляют меня и моих коллег. Я надеюсь на дальнейшее сотрудничество и уверен, что вместе мы сможем достичь еще больших успехов.


**Еще раз спасибо за Вашу поддержку и помощь.** 

:::



:::tip
Хочу выразить огромную благодарность всей команде **"Майской Революции"**

Их сплочённость и внимательность позволила мне разработать данную методичку.


Благодаря ним, данный материал может развиться из обычной шпаргалки к Экзамену в документацию к самому ДЕМО экзамену!


🥇Благодарю золотых спонсоров данного материала - Мимимишного "**Ramen"** и Умнейшего "**Hideyoshu"**!


📝Также благодарю и тех, кто участвовал в сборе информации и проверке правильности методички с точки зрения стендов на экзамене - Мощный "**adsarf"**, Бунтарский "**Yablochko076"** 


🎉И за моральную поддержку - Изысканный "**W.R. D.R."**, Анимешный "**Ozavrr**", Умная "**HastyaRe**", Теоретический "**cherni chayok**", Скрытный "**panpan**"

\nС признательностью,

Ваш вечный слуга - 🥕 **DSvinka**

:::
