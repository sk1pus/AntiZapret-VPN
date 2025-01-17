#!/bin/bash
set -e
#
# Скрипт для автоматического развертывания AntiZapret VPN + обычный VPN
# Версия от 28.08.2024
#
# https://github.com/GubernievS/AntiZapret-VPN
#
# Протестировано на Ubuntu 22.04/24.04 и Debian 11/12 - Процессор: 1 core Память: 1 Gb Хранилище: 10 Gb
#
# Установка:
# 1. Устанавливать на Ubuntu 22.04/24.04 или Debian 11/12 (рекомендуется Ubuntu 24.04 или Debian 12)
# 2. В терминале под root выполнить:
# apt-get update && apt-get install -y git
# git clone https://github.com/GubernievS/AntiZapret-VPN.git antizapret-vpn
# chmod +x antizapret-vpn/setup.sh && antizapret-vpn/setup.sh
# 3. Дождаться перезагрузки сервера и скопировать файлы *.ovpn с сервера из папки /root
#
# Обсуждение скрипта: https://ntc.party/t/9270
#
# Изменить файл с предзаполненным списком антизапрета (include-hosts-custom.txt):
# nano /root/antizapret/config/include-hosts-custom.txt
# Потом выполнить команду для обновления списка антизапрета:
# /root/antizapret/doall.sh
#
# Для добавления нового клиента выполните команду и введите имя:
# /root/add-client.sh [имя_пользователя]
# Скопируйте новые файлы *.ovpn с сервера из папки /root
#
# Для удаления клиента выполните команду и введите имя:
# /root/delete-client.sh [имя_пользователя]
#
# Для включения DCO в OpenVpn 2.6+ выполните команду:
# /root/enable-openvpn-dco.sh
#
# Для выключения DCO выполните команду:
# /root/disable-openvpn-dco.sh

#
# Обновляем систему
apt-get update && apt-get full-upgrade -y && apt-get autoremove -y

#
# Ставим необходимые пакеты
DEBIAN_FRONTEND=noninteractive apt-get install -y git curl iptables easy-rsa ferm gawk openvpn knot-resolver python3-dnslib idn sipcalc

#
# Обновляем antizapret до последней версии из репозитория
rm -rf /root/antizapret
git clone https://bitbucket.org/anticensority/antizapret-pac-generator-light.git /root/antizapret

#
# Исправляем шаблон для корректной работы gawk начиная с версии 5
sed -i "s/\\\_/_/" /root/antizapret/parse.sh

#
# Копируем нужные файлы и папки, удаляем не нужные
find /root/antizapret -name '*.gitkeep' -delete
rm -rf /root/antizapret/.git
find /root/antizapret-vpn -name '*.gitkeep' -delete
cp -r /root/antizapret-vpn/setup/* / 
rm -rf /root/antizapret-vpn

#
# Выставляем разрешения на запуск скриптов
find /root -name "*.sh" -execdir chmod u+x {} +
chmod +x /root/dnsmap/proxy.py

#
# Создаем пользователя 'client', его ключи 'antizapret-client', ключи сервера  'antizapret-server' и создаем ovpn файлы подключений в /etc/openvpn/client
/root/add-client.sh client

#
# Добавляем AdGuard DNS для блокировки рекламы, отслеживающих модулей и фишинга
echo "
policy.add(policy.all(policy.FORWARD({'94.140.14.14'})))
policy.add(policy.all(policy.FORWARD({'94.140.15.15'})))" >> /etc/knot-resolver/kresd.conf

#
# Запустим все необходимые службы при загрузке
systemctl enable kresd@1
systemctl enable antizapret-update.service
systemctl enable antizapret-update.timer
systemctl enable dnsmap
systemctl enable openvpn-server@antizapret-udp
systemctl enable openvpn-server@antizapret-tcp
systemctl enable openvpn-server@vpn-udp
systemctl enable openvpn-server@vpn-tcp


##################################
#     Настраиваем исключения     #
##################################

#
# Добавляем свои адреса в исключения
echo "youtube.com
googlevideo.com
ytimg.com
ggpht.com
googleapis.com
gstatic.com
gvt1.com
gvt2.com
gvt3.com
digitalocean.com
adguard-vpn.com
signal.org
hetzner.com" > /root/antizapret/config/include-hosts-custom.txt

#
# Ограничивают доступ из РФ - https://github.com/dartraiden/no-russia-hosts/blob/master/hosts.txt
# (список примерный и скопирован не весь)
echo "copilot.microsoft.com
4pda.to
habr.com
cisco.com
dell.com
dellcdn.com
fujitsu.com
deezer.com
fluke.com
formula1.com
intel.com
nordvpn.com
qualcomm.com
strava.com
openai.com
intercomcdn.com
oaistatic.com
oaiusercontent.com
chatgpt.com
bosch.de
download.jetbrains.com
software-static.download.prss.microsoft.com
weather.com" >> /root/antizapret/config/include-hosts-custom.txt

#
# Внереестровые блокировки  - https://bitbucket.org/anticensority/russian-unlisted-blocks/src/master/readme.txt
echo "tor.eff.org
news.google.com
play.google.com
twimg.com
bbc.co.uk
bbci.co.uk
radiojar.com
xvideos.com
doubleclick.net
windscribe.com
vpngate.net
rebrand.ly
adguard.com
antizapret.prostovpn.org
avira.com
mullvad.net
invent.kde.org
s-trade.com
ua
is.gd
1plus1tv.ru
linktr.ee
is.gd
anicult.org
12putinu.net
padlet.com
tlsext.com" >> /root/antizapret/config/include-hosts-custom.txt

#
# Удаляем исключения из исключений
#echo "" > /root/antizapret/config/exclude-hosts-dist.txt
sed -i "/\b\(youtube\|youtu\|ytimg\|ggpht\|googleusercontent\|cloudfront\|ftcdn\)\b/d" /root/antizapret/config/exclude-hosts-dist.txt
sed -i "/\b\(googleusercontent\|cloudfront\|deviantart\)\b/d" /root/antizapret/config/exclude-regexp-dist.awk

#
# Перезагружаем
reboot