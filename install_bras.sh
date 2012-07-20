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

NEED_INSTALL=1

if which pacman &> /dev/null; then
    XL2TPD_PATH="/etc/rc.d"
    INSTALL_CMD="pacman -U"
    UNINSTALL_CMD="pacman -R"
    if [ $(uname -m) = "i686" ]; then
        XL2TPD_PACKAGE=xl2tpd-1.3.0-1-i686.pkg.tar.xz
    else
        XL2TPD_PACKAGE=xl2tpd-1.3.0-1-x86_64.pkg.tar.xz
    fi
elif which dpkg &> /dev/null; then
    XL2TPD_PATH="/etc/init.d"
    INSTALL_CMD="dpkg -i"
    UNINSTALL_CMD="dpkg -P"
    if [ $(uname -m) = "i686" ]; then
        XL2TPD_PACKAGE=xl2tpd_1.2.7_dfsg-1_i386.deb
    else
        XL2TPD_PACKAGE=xl2tpd_1.2.7_dfsg-1_amd64.deb
    fi
elif which rpm &> /dev/null; then
    XL2TPD_PATH="/etc/rc.d/init.d"
    INSTALL_CMD="rpm -i"
    UNINSTALL_CMD="rpm -e"
    if [ $(uname -m) = "i686" ]; then
        XL2TPD_PACKAGE=xl2tpd-1.3.0-1.fc16.i686.rpm
    else
        XL2TPD_PACKAGE=xl2tpd-1.3.0-1.fc16.x86_64.rpm
    fi
else
    NEEED_INSTALL=0
    UNINSTALL_CMD="echo 'You have to manually remove'"
    echo "It seems that your system doesn't support package of deb or rpm."
    echo "You have to manually install xl2tpd."
fi

while [ -z "$BRAS_ID" ]; do
    read -p "BRAS_ID: " BRAS_ID
done

while [ -z "$BRAS_PASSWORD" ]; do
    read -s -p "BRAS_PASSWORD: (Input is hidden.)" BRAS_PASSWORD
done
echo

if which xl2tpd &> /dev/null; then
    echo "It seems that the xl2tpd was manually installed."
    echo "Please specify the path of xl2tpd, such as /etc/rc.d"
    while [ -z "$XL2TPD_PATH" ]; do
        read -p "xl2tpd path: " XL2TPD_PATH
    done
elif [ "$NEED_INSTALL" = "1" ]; then
    wget --no-proxy http://bbs.nju.edu.cn/file/S/silverzhao/$XL2TPD_PACKAGE
    $INSTALL_CMD $XL2TPD_PACKAGE
    rm -f $XL2TPD_PACKAGE
fi

if ! which xl2tpd &> /dev/null; then
    echo "Oops! It seems that xl2tpd hasn't been installed."
    echo "Please install it first."
    exit 2
fi

cat > /etc/xl2tpd/xl2tpd.conf << EEOOFF
[lac bras]
lns = 172.21.100.100
name = $BRAS_ID
pppoptfile = /etc/ppp/options.bras
EEOOFF

if [ -e /etc/ppp/options ]; then
    mv /etc/ppp/options /etc/ppp/options.bak
fi

cat > /etc/ppp/options.bras << EEOOFF
noauth
nodefaultroute
EEOOFF

cat > /etc/ppp/chap-secrets << EEOOFF
# client    server    secret    IP addresses
$BRAS_ID    *    $BRAS_PASSWORD    *
EEOOFF

mkdir -p /usr/local/sbin

sed -e "s:XL2TPD_PATH:$XL2TPD_PATH:" \
> /usr/local/sbin/bras-ctrl << "EEOOFF"
#!/bin/bash

case $1 in
route)
{
    if [ "$2" = "add" ]; then
        GATEWAY=$(ip route | grep "default" | awk '{print $3}')
        ip route replace default dev ppp0
    elif [ "$2" = "del" ]; then
        GATEWAY=$(ip route | grep "219.219.112.0" | awk '{print $3}')
        if ! ip route | grep -q "default"; then
            ip route add default via $GATEWAY
        fi
    else
        exit 1
    fi

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

if which ifconfig &> /dev/null; then
    DETECT_PPP='ifconfig | grep -q "ppp0"'
else
    DETECT_PPP='ip link show ppp0 &> /dev/null'
fi

cat > /usr/local/sbin/brasup << EEOOFF
#!/bin/bash

bras-ctrl start
while ! $DETECT_PPP; do
    sleep 1
done
bras-ctrl route add

exit 0
EEOOFF

cat > /usr/local/sbin/brasdown << EEOOFF
#!/bin/bash

bras-ctrl stop
bras-ctrl route del

exit 0
EEOOFF

cat > /usr/local/sbin/bras-uninstall << EEOOFF
#!/bin/bash

echo "removing config file..."
rm -f /usr/local/sbin/bras-ctrl \
      /usr/local/sbin/brasup \
      /usr/local/sbin/brasdown \
      /etc/xl2tpd/xl2tpd.conf \
      /etc/ppp/options.bras \
      /etc/ppp/options.bak \
      /etc/ppp/chap-secrets
echo "removing xl2tpd..."
$UNINSTALL_CMD xl2tpd
echo "Done!"
rm -f /usr/local/sbin/bras-uninstall

exit 0
EEOOFF

chmod +x /usr/local/sbin/bras-ctrl
chmod +x /usr/local/sbin/brasup
chmod +x /usr/local/sbin/brasdown
chmod +x /usr/local/sbin/bras-uninstall

if ! grep -q "/usr/local/sbin" /etc/profile; then
    sed -i 's#^PATH="#&/usr/local/sbin:#' /etc/profile
fi

export PATH=$PATH:/usr/local/sbin

echo "
##################################
#       Install Completed!       #
#     try 'sudo brasup' now.     #
# if anything wrong, try reboot. #
##################################
"
exit 0

