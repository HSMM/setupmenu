#!/bin/bash
# Отправка статистики сервера Asterisk на сервер Zabbix

# Массив пар строк команда Asterisk  - строка awk-программы для обработки строки
# ответа команды
aComAwk=(
 'core show uptime seconds' '/System uptime:/ { print "uptime", int($4) }'
 'core show threads' '/threads listed/ { print "threads", int($2) }'
 'voicemail show users' '/voicemail users configured/ { print "voicemail.users", int($2) } BEGIN { m = 0 } /^default/ { m += int($NF) } END { print "voicemail.messages", m }'
 'sip show channels' '/active SIP/ { print "sip.channels.active", int($2) }'
 'iax2 show channels' '/active IAX/ { print "iax2.channels.active", int($2) }'
 'sip show peers' '/sip peers/ { print "sip.peers", int($2); print "sip.peers.online", int($6) + int($11) }'
 'iax2 show peers' '/iax2 peers/ { print "iax2.peers", int($2) }'
 'core show channels' '/active channels/ { print "channels.active", int($2) } /active calls/ { print "calls.active", int($2) } /calls processed/ { print "calls.processed", int($2) }'
 'xmpp show connections' '/Number of clients:/ { print "xmpp.connections", int($NF) }'
 'sip show subscriptions' '/active SIP subscriptions/ { print "sip.subscriptions", int($2) }'
 'sip show registry' '/SIP registrations/ { print "sip.registrations", int($2) } BEGIN { r = 0 } /Registered/ { r += 1 } END { print "sip.registered", int(r) }'
 'iax2 show registry' '/IAX2 registrations/ { print "iax2.registrations", int($2) } BEGIN { r = 0 } /Registered/ { r += 1 } END { print "iax2.registered", int(r) }'
 'pjsip show aors' '/Objects found:/ { print "pjsip.aors.all", int($4) } BEGIN { r = 0 } /Avail/ { r += 1 } END { print "pjsip.aors.avail", int(r) }'
 'pjsip show auths' '/Objects found:/ { print "pjsip.auths", int($4) }'
 'pjsip show channels' '/Objects found:/ { print "pjsip.channels", int($4) }'
 'pjsip show contacts' '/Objects found:/ { print "pjsip.contacts.all", int($4) } BEGIN { r = 0 } /Avail/ { r += 1 } END { print "pjsip.contacts.avail", int(r) }'
 'pjsip show endpoints' '/Objects found:/ { print "pjsip.endpoints.all", int($4) } BEGIN { r = 0 } /Avail/ { r += 1 } END { print "pjsip.endpoints.avail", int(r) }'
 'pjsip show identifies' '/Objects found:/ { print "pjsip.identifies", int($4) }'
 'pjsip show registrations' '/Objects found:/ { print "pjsip.registrations", int($4) } BEGIN { r = 0 } /Registered/ { r += 1 } END { print "pjsip.registered", int(r) }'
)

# Формирование строки команд Asterisk из строк команд массива
CommandStr=$(
 for(( i = 0; i < ${#aComAwk[@]}; i += 2 )); do
  echo -n "Action: command\r\nCommand: ${aComAwk[i]}\r\n\r\n"
 done
)

# Выполнение команд Asterisk через AMI интерфейс
ResStr=$(/bin/echo -e "Action: Login\r\nUsername: zabbix\r\nSecret: zabbix\r\nEvents: off\r\n\r\n${CommandStr}Action: Logoff\r\n\r\n" | /usr/bin/nc 127.0.0.1 5038 2>/dev/null)
# Статистика недоступна - возврат статуса сервиса - 'не работает'
[ $? != 0 ] && echo 0 && exit 1

# Индекс строки awk-программ в массиве
iAwk=1
# Разделитель полей во вводимой строке - для построчной обработки
IFS=$'\n'
# Строка вывода
OutStr=$(
 # Построчная обработка строки результатов выполнения команд
 for rs in $ResStr; do
  # Позиция начала следующей строки в строке результатов
  let "pos+=${#rs}+1"
  # Строка сообщения вывода выполнения команды
  if [ "${rs}" = "Message: Command output follows"$'\r' ]; then
   # Сохранение позиции начала подстроки результата в строке результатов
   begin=$pos
  # Строка конца подстроки результата выполнения команды
  elif [[ "${rs:0:7}" != 'Output:' && -n "$begin" ]]; then
   # Выполнение awk-программы над подстрокой результата выполнения команды
   (cat <<EOF
${ResStr:$begin:$pos-$begin}
EOF
   ) | awk "${aComAwk[iAwk]}"
   # Переключение индекса строки awk-программы в массиве на следующую
   let "iAwk+=2"
   # Очистка позиции начала подстроки результата в строке результатов
   begin=
  fi
 # Вставка в начало каждой строки
 done | awk '{ print "- asterisk."$0 }'
)

# Идентификатор процесса Asterisk из PID-файла
pid=$(/bin/cat /var/run/asterisk/asterisk.pid 2>/dev/null)
# PID-файл отсутствует - возврат статуса сервиса - 'не работает'
[ -z "$pid" ] && echo 0 && exit 1
# Строка вывода использования CPU и памяти процессом Asterisk
OutStr1=$((/bin/ps --no-headers --pid $pid --ppid $pid -o pcpu,rssize || echo 0 0) | awk '{ c+=$1; m+=$2 } END { print "- asterisk.pcpu", c; print "- asterisk.memory", m*1024 }')

# Отправка строки вывода серверу Zabbix. Параметры zabbix_sender:
#  --config		файл конфигурации агента;
#  --host		имя узла сети на сервере Zabbix;
#  --input-file		файл данных('-' - стандартный ввод)
(cat<<EOF
$OutStr
$OutStr1
EOF
) | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Возврат статуса сервиса - 'работает'
echo 1
exit 0
