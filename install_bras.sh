#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

echo "
##################################
#       Installing Bras...       #
##################################
"

if [ $UID -ne 0 ]; then
    echo "It seems that you are not root. Please try again."
    exit 1
fi

if uname -a | grep "ARCH" &> /dev/null; then
    XL2TPD_PATH='\/etc\/rc.d'
    XL2TPD_PACKAGE=xl2tpd-1.3.0-1-i686.pkg.tar.xz
    INSTALL_CMD="pacman -U"
    NEED_INSTALL=1
elif uname -a | grep "Ubuntu" &> /dev/null; then
    XL2TPD_PATH='\/etc\/init.d'
    XL2TPD_PACKAGE=xl2tpd_1.2.7_dfsg-1_i386.deb
    INSTALL_CMD="dpkg -i"
    NEED_INSTALL=1
elif uname -a | grep "fc" &> /dev/null; then
    XL2TPD_PATH='\/etc\/rc.d\/init.d'
    XL2TPD_PACKAGE=xl2tpd-1.3.0-1.fc16.i686.rpm
    INSTALL_CMD="yum localinstall"
    NEED_INSTALL=1
else
    NEEED_INSTALL=0
    echo "Are you using Archlinux/Ubuntu/Fedora? \
If not, maybe you have to manually install xl2tpd first."
fi

while [ -z "$BRAS_ID" ]; do
    read -p 'BRAS_ID: ' BRAS_ID
done

while [ -z "$BRAS_PASSWORD" ]; do
    read -s -p 'BRAS_PASSWORD: (Input is hidden.)' BRAS_PASSWORD
done
echo ""

GATEWAY=$(ip route | grep 'default' | awk '{print $3}')

if ! which xl2tpd &> /dev/null && [ $NEED_INSTALL = "1" ]; then
    wget --no-proxy http://bbs.nju.edu.cn/file/S/silverzhao/$XL2TPD_PACKAGE
    $INSTALL_CMD $XL2TPD_PACKAGE
    rm -f $XL2TPD_PACKAGE
fi

if ! which xl2tpd &> /dev/null; then
    echo "Oops! It seems that xl2tpd hasn't been installed. \
Please install it first."
    exit 2
fi

sed -e "s/BRAS_ID/$BRAS_ID/" > /etc/xl2tpd/xl2tpd.conf << "EEOOFF" 
[lac bras]
lns = 172.21.100.100
name = BRAS_ID
pppoptfile = /etc/ppp/options.bras
EEOOFF

cat > /etc/ppp/options.bras << "EEOOFF"
noauth
nodefaultroute
EEOOFF

sed -e "s/BRAS_ID/$BRAS_ID/" -e "s/BRAS_PASSWORD/$BRAS_PASSWORD/" \
> /etc/ppp/chap-secrets << "EEOOFF" 
# client	server	secret	IP addresses
BRAS_ID	*	BRAS_PASSWORD	*
EEOOFF

mkdir -p /usr/local/sbin

sed -e "s/172.25.49.1/$GATEWAY/" -e "s/XL2TPD_PATH/$XL2TPD_PATH/" \
> /usr/local/sbin/bras-ctrl << "EEOOFF"
#!/bin/bash

case $1 in
route)
GATEWAY=172.25.49.1
{
    ip route $2 58.192.32.0/20 via $GATEWAY
    ip route $2 58.192.48.0/21 via $GATEWAY
    ip route $2 114.212.0.0/16 via $GATEWAY
    ip route $2 172.16.0.0/12 via $GATEWAY
    ip route $2 202.38.2.0/24 via $GATEWAY
    ip route $2 202.38.3.0/24 via $GATEWAY
    ip route $2 202.38.126.160/28 via $GATEWAY
    ip route $2 202.119.32.0/19 via $GATEWAY
    ip route $2 202.127.247.0/24 via $GATEWAY
    ip route $2 210.28.128.0/20 via $GATEWAY
    ip route $2 210.29.240.0/20 via $GATEWAY
    ip route $2 219.219.112.0/20 via $GATEWAY

    if [ "$2" = "add" ]; then
	ip route replace default dev ppp0
    elif [ "$2" = "del" ]; then
	ip route replace default via $GATEWAY
    fi
} &> /dev/null
;;

start)
    XL2TPD_PATH/xl2tpd start
    sh -c 'echo "c bras" > /var/run/xl2tpd/l2tp-control'
    ;;

stop)
    sh -c 'echo "d bras" > /var/run/xl2tpd/l2tp-control'
    XL2TPD_PATH/xl2tpd stop
    ;;

*)
    echo "Please specify your action: route add/del | start | stop"
    ;;
esac
EEOOFF
chmod +x /usr/local/sbin/bras-ctrl

cat > /usr/local/sbin/brasup << "EEOOFF"

#!/bin/bash

bras-ctrl start
while ! ifconfig | grep "ppp" > /dev/null 2>&1; do
    sleep 1
done
bras-ctrl route add

exit 0
EEOOFF
chmod +x /usr/local/sbin/brasup

cat > /usr/local/sbin/brasdown << "EEOOFF"
#!/bin/bash

bras-ctrl stop
bras-ctrl route del

exit 0
EEOOFF
chmod +x /usr/local/sbin/brasdown

sed -i 's/^PATH="/&\/usr\/local\/sbin:/' /etc/profile
export PATH=$PATH:/usr/local/sbin

echo "
##################################
#       Install Completed!       #
#     try 'sudo brasup' now.     #
# if anything wrong, try reboot. #
##################################
"
exit 0

