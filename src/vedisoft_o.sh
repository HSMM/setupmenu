#!/bin/bash
#простыезвонки фикс

arc=`arch`
if [ "$arc" == "x86_64" ];
then arc=64
else arc=86
fi
prosto=$(fwconsole ma list | grep -ow prostiezvonki)
astver=$(asterisk -V | grep -woE [0-9]+\.)

end()
{
echo -e "Нажмите любую клавишу чтобы вернуться в меню"
read -s -n 1
}
#Останавливаем астериск на всякий случай, по завершинии подмены запускаем обратно.
service asterisk stop
#Сносим старые сошки
rm -rvf /usr/lib/asterisk/modules/cel_prostiezvonki.so
rm -rvf /usr/lib64/asterisk/modules/cel_prostiezvonki.so
rm -rvf /usr/lib/libProtocolLib.so
rm -rvf /usr/lib64/libProtocolLib.so
rm -rvf /tmp/prost*
echo "обновляем файлы для $astver x$arc"
#Проверяем версию астериска и разрядность, закидываем новые файлы
if [ "$astver" == "13" ];
then
if [ "$arc" == "64" ];
	then
#Для 13 x64
cd /tmp
wget http://prostiezvonki.ru/installs/prostiezvonki_asterisk13.zip
unzip prostiezvonki_asterisk13.zip
cd /tmp/prostiezvonki/so/64/
cp /tmp/prostiezvonki/so/64/cel_prostiezvonki.so /usr/lib/asterisk/modules/
cp /tmp/prostiezvonki/so/64/cel_prostiezvonki.so /usr/lib64/asterisk/modules/
cp /tmp/prostiezvonki/so/64/libProtocolLib.so /usr/lib/
cp /tmp/prostiezvonki/so/64/libProtocolLib.so /usr/lib64/
fwconsole reload
service asterisk start
else
#Для 13 x86
cd /tmp
wget http://prostiezvonki.ru/installs/prostiezvonki_asterisk13.zip
unzip prostiezvonki_asterisk13.zip
cd /tmp/prostiezvonki/so/32/
cp /tmp/prostiezvonki/so/32/cel_prostiezvonki.so /usr/lib/asterisk/modules/
cp /tmp/prostiezvonki/so/32/libProtocolLib.so /usr/lib/
fwconsole reload
service asterisk start
fi
    else
    #Для 11 x64
    if [ "$arc" == "64" ];
	then
    cd /tmp
    wget http://prostiezvonki.ru/installs/prostiezvonki_asterisk11.zip
    unzip prostiezvonki_asterisk11.zip
    cd /tmp/prostiezvonki/so/64/
    cp /tmp/prostiezvonki/so/64/cel_prostiezvonki.so /usr/lib/asterisk/modules/
    cp /tmp/prostiezvonki/so/64/cel_prostiezvonki.so /usr/lib64/asterisk/modules/
    cp /tmp/prostiezvonki/so/64/libProtocolLib.so /usr/lib/
    cp /tmp/prostiezvonki/so/64/libProtocolLib.so /usr/lib64/
    fwconsole reload
    service asterisk start
    else
    #Для 11 x86
    cd /tmp
    wget http://prostiezvonki.ru/installs/prostiezvonki_asterisk11.zip
    unzip prostiezvonki_asterisk11.zip
    cd /tmp/prostiezvonki/so/32/
    cp /tmp/prostiezvonki/so/32/cel_prostiezvonki.so /usr/lib/asterisk/modules/
    cp /tmp/prostiezvonki/so/32/libProtocolLib.so /usr/lib/
    fwconsole reload
    service asterisk start
    fi
fi
#Чистим за собой
rm -rvf /tmp/prost*
#Проверяем смотрим чтобы поднялся порт 10150
sleep 2
asterisk -rx "module show like cel_prostiezvonki.so"
netstat -tulpn | grep 10150
echo "Обновлены so файлы для asterisk $astver x$arc"
end
