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

SUPPORTED=1

if which pacman &> /dev/null; then
    XL2TPD_PATH="/etc/rc.d"
    INSTALL_CMD="pacman -U"
    UNINSTALL_CMD="pacman -R"
    if [ $(uname -m) = "i686" ]; then
        XL2TPD_PACKAGE="xl2tpd-1.3.0-1-i686.pkg.tar.xz"
    else
        XL2TPD_PACKAGE="xl2tpd-1.3.0-1-x86_64.pkg.tar.xz"
    fi
elif which dpkg &> /dev/null; then
    XL2TPD_PATH="/etc/init.d"
    INSTALL_CMD="dpkg -i"
    UNINSTALL_CMD="dpkg -P"
    if [ $(uname -m) = "i686" ]; then
        XL2TPD_PACKAGE="xl2tpd_1.2.7_dfsg-1_i386.deb"
    else
        XL2TPD_PACKAGE="xl2tpd_1.2.7_dfsg-1_amd64.deb"
    fi
elif which rpm &> /dev/null; then
    XL2TPD_PATH="/etc/rc.d/init.d"
    INSTALL_CMD="rpm -i"
    UNINSTALL_CMD="rpm -e"
    if [ $(uname -m) = "i686" ]; then
        XL2TPD_PACKAGE="xl2tpd-1.3.0-1.fc16.i686.rpm"
    else
        XL2TPD_PACKAGE="xl2tpd-1.3.0-1.fc16.x86_64.rpm"
    fi
else
    SUPPORTED=0
    echo "It seems that your system doesn't support package of deb or rpm."
    echo "You have to manually install xl2tpd."
fi

if [ -z "$1" ]; then
    BRAS_OUT_ID=test_bras_out_id
    BRAS_OUT_PASSWORD=test_bras_out_pwd
else
    echo "For bras *IN* campus:"
fi

while [ -z "$BRAS_ID" ]; do
    read -p "BRAS_ID: " BRAS_ID
done

while [ -z "$BRAS_PASSWORD" ]; do
    read -s -p "BRAS_PASSWORD: (Input is hidden.)" BRAS_PASSWORD
done
echo

if [ -n "$1" ]; then
    echo
    echo "For bras *OFF* campus:"
fi

while [ -z "$BRAS_OUT_ID" ]; do
    read -p "BRAS_OUT_ID: " BRAS_OUT_ID
done

while [ -z "$BRAS_OUT_PASSWORD" ]; do
    read -s -p "BRAS_OUT_PASSWORD: (Input is hidden.)" BRAS_OUT_PASSWORD
done
echo
echo

if which xl2tpd &> /dev/null; then
    UNINSTALL_CMD="echo 'You have to manually remove'"
    echo "It seems that the xl2tpd was manually installed."
    echo "Please specify the directory containing xl2tpd daemon, such as:"
	echo "/etc/init.d ==> for Ubuntu"
    echo "/etc/rc.d/init.d ==> for Fedora"
	echo "/etc/rc.d ==> for Arch"
    XL2TPD_PATH=
    while [ -z "$XL2TPD_PATH" ]; do
        read -p "xl2tpd path: " XL2TPD_PATH
    done
elif [ "$SUPPORTED" = "1" ]; then
    wget --no-proxy http://bbs.nju.edu.cn/file/S/silverzhao/$XL2TPD_PACKAGE
    $INSTALL_CMD $XL2TPD_PACKAGE
    rm -f $XL2TPD_PACKAGE
fi

if ! which xl2tpd &> /dev/null; then
    echo "Oops! It seems that xl2tpd hasn't been installed."
    echo "Please install it first."
    exit 2
fi

XL2TPD_CONFIG_FILE="/etc/xl2tpd/xl2tpd.conf"
BRAS_CONFIG_FILE="/etc/ppp/peers/bras"
BRAS_OUT_CONFIG_FILE="/etc/ppp/peers/bras_out"
BRAS_SECRET_FILE="/etc/ppp/chap-secrets"

cat > $XL2TPD_CONFIG_FILE << EEOOFF
[lac bras]
lns = 172.21.100.100
pppoptfile = $BRAS_CONFIG_FILE

[lac bras_out]
lns = 218.94.142.114
pppoptfile = $BRAS_OUT_CONFIG_FILE
EEOOFF

[ -e /etc/ppp/options ] && mv /etc/ppp/options /etc/ppp/options.bak

cat > $BRAS_CONFIG_FILE << EEOOFF
user $BRAS_ID
noauth
nodefaultroute
EEOOFF

cat > $BRAS_OUT_CONFIG_FILE << EEOOFF
user $BRAS_OUT_ID
noauth
nodefaultroute
usepeerdns
mtu 1452
EEOOFF

cat > $BRAS_SECRET_FILE << EEOOFF
# client    server    secret    IP addresses
# for bras in-campus
$BRAS_ID    *    $BRAS_PASSWORD    *

# for bras off-campus
$BRAS_OUT_ID    *    $BRAS_OUT_PASSWORD    *
EEOOFF
chmod 600 $BRAS_SECRET_FILE

BRAS_BIN_DIR="/usr/local/sbin"

mkdir -p $BRAS_BIN_DIR

sed -e "s:XL2TPD_PATH:$XL2TPD_PATH:" > $BRAS_BIN_DIR/bras-ctrl << "EEOOFF"
#!/bin/bash

case $1 in
route)
{
    if [ "$2" = "add" ]; then
        if [ -z "$3" ]; then
            GATEWAY=$(ip route | grep "default" | awk '{print $3}')
            ip route replace default dev ppp0
        else
            GATEWAY=$(ip route | grep "180.209" | awk '{print $1}')
        fi
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
    if [ -z "$2" ]; then
        sh -c 'echo "c bras" > /var/run/xl2tpd/l2tp-control'
    else
        sh -c 'echo "c bras_out" > /var/run/xl2tpd/l2tp-control'
    fi
    ;;
    
stop)
    if [ -z "$2" ]; then
        sh -c 'echo "d bras" > /var/run/xl2tpd/l2tp-control'
    else
        sh -c 'echo "d bras_out" > /var/run/xl2tpd/l2tp-control'
    fi
    XL2TPD_PATH/xl2tpd stop
    ;;

*)
    echo "Please specify your action: route add/del | start | stop"
    ;;
esac
EEOOFF

if which ifconfig &> /dev/null; then
    DETECT_PPP="ifconfig | grep -q 'ppp0'"
else
    DETECT_PPP="ip link show ppp0 &> /dev/null"
fi

sed -e "s:DETECT_PPP:$DETECT_PPP:" > $BRAS_BIN_DIR/brasup << "EEOOFF"
#!/bin/bash

bras-ctrl start $1

if [ -z "$1" ]; then
    BRAS_DONE="DETECT_PPP"
else
    BRAS_DONE="ip route | grep -q '180.209'"
fi

while ! eval "$BRAS_DONE"; do
    sleep 1
done

bras-ctrl route add $1

exit 0
EEOOFF

cat > $BRAS_BIN_DIR/brasdown << "EEOOFF"
#!/bin/bash

bras-ctrl stop $1
if [ -z "$1" ]; then
    bras-ctrl route del
fi

exit 0
EEOOFF

cat > $BRAS_BIN_DIR/bras-uninstall << EEOOFF
#!/bin/bash

echo "
##################################
#      Uninstalling Bras...      #
##################################
"
echo "removing config file..."
rm -f $BRAS_BIN_DIR/bras-ctrl \\
      $BRAS_BIN_DIR/brasup \\
      $BRAS_BIN_DIR/brasdown \\
      $XL2TPD_CONFIG_FILE \\
      $BRAS_CONFIG_FILE \\
      $BRAS_OUT_CONFIG_FILE \\
      $BRAS_SECRET_FILE \\
      /etc/ppp/options.bak
echo "removing xl2tpd..."
$UNINSTALL_CMD xl2tpd
echo "Done!"
rm -f $BRAS_BIN_DIR/bras-uninstall

exit 0
EEOOFF

chmod +x $BRAS_BIN_DIR/bras-ctrl
chmod +x $BRAS_BIN_DIR/brasup
chmod +x $BRAS_BIN_DIR/brasdown
chmod +x $BRAS_BIN_DIR/bras-uninstall

if ! grep -q "$BRAS_BIN_DIR" /etc/profile; then
    sed -i "s#^PATH=\"#&$BRAS_BIN_DIR:#" /etc/profile
fi

export PATH=$PATH:$BRAS_BIN_DIR

echo "
##################################
#       Install Completed!       #
#     try 'sudo brasup' now.     #
# if anything wrong, try reboot. #
##################################
"
exit 0

