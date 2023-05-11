# Создание отказоустойчивого кластера с балансировкой нагрузки

## Задание

В гипервизоре создать виртуальные машины, пробрасывающие трафик через физический интерфейс (в bridge-режиме).
Машины должны эмулировать виртуальные сервера.
Для `fit.nsu` и `fit2.nsu` должны существовать виртуальные хосты Apache.
DNS-сервер должен обслуживать зону `.nsu`.

## Используемые инструменты

1. **Haproxy** – серверное программное обеспечение для обеспечения высокой доступности и балансировки нагрузки для приложений, посредством распределения входящих запросов на несколько обслуживающих серверов.
2. **Pacemaker** – программное обеспечение для обеспечения высокой доступности и отказоустойчивости приложений, которые работают на кластере.
3. **Corosync** – проект с открытым исходным кодом, реализующий систему группового общения для отказоустойчивых кластеров.
4. **Apache** – свободный веб-сервер.
5. **BIND9** – открытая и наиболее распространённая реализация DNS-сервера.
6. **VirtualBox** – программный продукт виртуализации для операционных систем Windows, Linux, FreeBSD, macOS, Solaris/OpenSolaris, ReactOS, DOS и других.

## Создание виртальных машин

1. Установить [Virtual Box](https://www.virtualbox.org/wiki/Downloads)
2. Скачивать образ [Debian](https://www.debian.org/CD/netinst/)
3. Создать виртуальной машины на основе образа:
    + 1 Гб оперативной памяти
    + 3 Гб HDD
4. Настроить сеть виртуальной машины:
    + Тип подключения – сетевой мост
5. Установить операционную систему:
    + Имя компьютера – node1
    + Пароль суперпользователя – 1234 (или придумай свой)
    + Имя нового пользователя – user
    + Пароль для нового пользователя – 4321 (или придумай свой)
    + Метод разметки – авто – использовать весь диск
    + Схема разметки – все файлы в одном разделе
    + Разметка дисков – закончить разметку и записать изменения на диск
    + Записать изменения на диск – да
    + Просканировать другой CD – нет
    + Страна, в которой расположено зеркало архива – РФ
    + Зеркало архива – `deb.debian.org`
    + Устанавливаемое ПО – ssh-сервер, стандартные системные утилиты.
    + Установить системный загрузчик GRUB в главную загрузочную запись – да
    + Устройство для установки системного загрузчика - `/dev/sda/`
6. Аналогично создать виртуальные машины с именами: node2, dns

## Рекомендация

Желательно сделать ip-адрес статическим при помощи настроек роутера, или изменив `/etc/network/interfaces`:

    ```text
        iface <имя сетевогог интерфейса> inet static
            address <статический адрес машины>
            netwask <маска сети>
            gateway <адрес шлюза по умолчанию>
    ```

## Настройка NODE1 и NODE2

### Подготовка

1. Зайти виртуальную машину node1 режиме администратора
2. Обновить пакеты:

    ```bash
        apt-get update
        apt-get upgrade
    ```

3. Для удобства можно установить `mc` – удобный файловый менеджер

    ```bash
        apt-get install mc
    ```

4. Установить `aptitude` - текстовый интерфейс для системы управления пакетами APT:

    ```bash
        apt-get install -y aptitude
    ```

5. Установить `Corosync`, `Pacemaker`, `Haproxy`, `Apache`:

    ```bash
        aptitude install corosync pacemaker haproxy apache2
    ```

### Настройка Corosync

1. Отредактировать `/etc/corosync/corosync.conf`:

   + Директива `totem`:

        ```text
            interface {
                ringnumber: 0
                bindnetaddr: <адрес сети кластера (IP-address & netmask)>
                broadcast: yes
            }
        ```

   + Директива `nodelist`:

        ```text
            node {
                name: node1
                nodeid: 1
                ring0_addr: <адрес машины node1>
            }

            node {
                name: node2
                nodeid: 2
                ring0_addr: <адрес машины node2>
            }
        ```

2. Повторить предыдущие настройки на машине NODE2
3. Сгенерировать ключ:

    ```bash
        corosync-keygen
    ```

4. Отправить сгенерированный ключ на NODE2:

    ```bash
        scp /etc/corosync/authkey user@<адрес машины node2>:.
    ```

5. На машине NODE2 переместить `authkey` в `/etc/corosync/`:

    ```bash
        mv /home/user/authkey /etc/corosync/
    ```

6. Добавить в `corosync` автозапуск:

    + Открыть `/etc/default/corosync`
    + Написать `START=yes`

7. Перезапустить виртуальную машину:

    ```bash
        reboot
    ```

8. Повторить предыдущие настройки на машине NODE2
9. Проверить настройки `corosync`:

    ```bash
        corosync-cmapctl | grep members
    ```

### Настройка Haproxy

1. Отредактировать `/etc/haproxy/haproxy.cfg`:
    + Дописывать в конец:

        ```text
            frontend front
                bind <адрес haproxy-сервера>:80
                default_backend back
            backend back
                balance roundrobin
                server node1 <адрес машины node1>:81 check
                server node2 <адрес машины node2>:81 check
        ```

        + `frontend` определяет, каким образом перенаправлять запросы к бэкенду в зависимости от того, что за запрос поступил от клиента.
        + `backend` содержит список серверов и отвечает за
        балансировку нагрузки между ними в зависимости от
        выбранного алгоритма.
        + 80 – порт для haproxy-сервера
        + 81 – порт для apache2-серверов.
        + `front` – название frontend'а
        + `bind <адрес haproxy-сервера>:80` – ip адрес и порт виртуального интерфейса haproxy-сервера
        + `default_backend back` – название backend'а, на который будут отправляться входящие запросы с frontend'а
        + `back` – название backend’а
        + `balance roundrobin` – алгоритм балансировки
        + `server node1 <адрес машины node1>:81 check`: `server` — имя и IP-адрес сервера, на который передается запрос, `check` — указываем, что необходимо проверять состояние сервера

2. Проверить настройки `haproxy`

    ```bash
        haproxy -f /etc/haproxy/haproxy.cfg -c
    ```

3. Передать настройки на NODE2

    ```bash
        scp /etc/haproxy/haproxy.cfg <адрес машины node2>:/etc/haproxy/haproxy.cfg
    ```

4. Добавить разрешение на привязку нелокального ip-адреса в `/etc/sysctl.conf` (на обоих узлах):

    ```bash
        net.ipv4.ip_nonlocal_bind=1
    ```

5. Полезные команды:

    ```bash
        service haproxy start
        service haproxy stop
        service haproxy reload
        service haproxy status
    ```

### Настройка Pacemaker

1. Установить `crmsh` - инструмент для упрощенной работы с
XML-файлами настройки Pacemaker’а, который распространяет
настройки сразу на все узлы, чем облегчает жизнь:

    ```bash
        aptitude install crmsh
    ```

2. Перейти в режим конфигурации:

    ```bash
        crm configure
    ```

3. Отключить необходимость набора 50% рабочих узлов кластер для
жизнеспособности кластера:

    ```bash
        property no-quorum-policy=ignore
    ```

4. Отключить Shoot-TheOther-Node-In-The-Head:

    ```bash
        property stonith-enabled=false
    ```

5. Создать виртуальный ip-адрес:

    ```bash
        primitive VIP ocf:heartbeat:IPaddr2 params ip=<адрес машины haproxy-сервера> cidr_netmask=<маска подсети> op monitor interval=1s
    ```

    С помощью `op monitor interval=1s` кластер
    будет следить за состоянием ресурса каждую секунду

6. Создать ресурс haproxy:

    ```bash
        primitive HAP lsb:haproxy op monitor interval=1s
    ```

7. Принудить к размещению ресурсов на одном узле или наоборот на
разных узлах:

    ```bash
        colocation CLC inf: VIP HAP
    ```

8. Определить порядок запуска ресурсов (сначала VIP, потом HAP, зависящий от VIP)

    ```bash
        order ORD inf: VIP HAP
    ```

9. Сохранить настройки:

    ```bash
        commit
    ```

10. Перезапустить виртуальную машину:

    ```bash
        reboot
    ```

11. Полезные утилиты:

    ```bash
        crm status
        crm configure show
    ```

### Настройка Apache

1. Отредактировать `/etc/apache2/ports.conf`:

    ```bash
        NameVirtualHost *:81
        Listen 81
    ```

2. Создать `/etc/apache2/sites-available/mysite.com.conf` и добавить 2 виртуальных хоста(сайта):

    ```xml
        <VirtualHost <адрес машины node1>:81>
            ServerName fit.nsu
            DocumentRoot /var/www/fit.nsu
        </VirtualHost>
        <VirtualHost <адрес машины node1>:81>
            ServerName fit2.nsu
            DocumentRoot /var/www/fit2.nsu
        </VirtualHost>
    ```

    + `ServerName fit.nsu` – доменное имя хоста
    + `DocumentRoot /var/www/fit.nsu` – директория, в которой находится сайт

3. Создать папки для сайтов:

    ```bash
        mkdir /var/www/fit.nsu
        mkdir /var/www/fit2.nsu
    ```

4. Создать стартовые страницы для сайтов:

    ```bash
        touch /var/www/fit.nsu/index.html
        touch /var/www/fit2.nsu/index.html
    ```

5. Добавить содержимое для `fit.nsu`:

    ```html
        <html>
            <header>
                <title>
                    This is title
                </title>
            </header>
            <body>
                Hello,I'm node1!(fit)
            </body>
        </html>
    ```

6. Добавить содержимое для `fit2.nsu`:

    ```html
        <html>
            <header>
                <title>
                    This is title
                </title>
            </header>
            <body>
                Hello,I'm node1!(fit2)
            </body>
        </html>
    ```

7. Запустить сайты:

    ```bash
        a2ensite mysite.com.conf
    ```

8. Запустить apache2:

    ```bash
        service apache2 start
    ```

9. Повторить предыдущие настройки на машине NODE2, заменяя адрес и название машины
10. Проверить работоспособность кластера:

    ```bash
        curl <адрес haproxy-сервера>
    ```

## Настройка DNS

1. Установить `BIND9`:

    ```bash
        aptitude install bind9
    ```

2. Создать новую зону:

    ```bash
        touch /etc/bind/db.nsu
    ```

3. Записать в `/etc/bind/db.nsu`:

    ```text
        $TTL 604800
        @     IN     SOA ns.nsu. root.nsu. (
                  6 ; Serial
                  10800 ; Refresh
                  3600 ; Retry
                  3600000 ; Expire
                  604800) ; Negative cache TTL
        ;
        @    IN   NS   ns.nsu.
        ns   IN   A    <адрес DNS-сервера>
        fit  IN   A    <адрес haproxy-сервера>
        fit2 IN   A    <адрес haproxy-сервера>
    ```

4. Добавить новую зону в `/etc/bind/named.conf.defaultzones`:

    ```bash
        zone "nsu" {
            type master;
            file "/etc/bind/db.nsu";
        };
    ```

5. Проверить корректность файла зон:

    ```bash
        named-checkconf -z
    ```

6. Обновить информацию о зонах:

    ```bash
        rndc reload
    ```

7. Добавить путь до DNS сервера в `/etc/network/interfaces`:

    ```text
        dns-nameservers <адрес DNS-сервера>
    ```

8. Проверить работоспособность DNS сервера:

    ```bash
        nslookup <имя сайта> <адрес DNS-сервера>
    ```
