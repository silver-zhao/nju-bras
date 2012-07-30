#!/bin/bash

echo "
##################################
#_______Installing Bras..._______#
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
    BRAS_UP_CONFIG="/etc/ppp/ip-up.d/09-bras.sh"
    if [ $(uname -m) = "i686" ]; then
        XL2TPD_PACKAGE="xl2tpd-1.3.0-2-i686.pkg.tar.xz"
    else
        XL2TPD_PACKAGE="xl2tpd-1.3.0-2-x86_64.pkg.tar.xz"
    fi
elif which dpkg &> /dev/null; then
    XL2TPD_PATH="/etc/init.d"
    INSTALL_CMD="dpkg -i"
    UNINSTALL_CMD="dpkg -P"
    BRAS_UP_CONFIG="/etc/ppp/ip-up.d/09bras"
    if [ $(uname -m) = "i686" ]; then
        XL2TPD_PACKAGE="xl2tpd_1.2.8_dfsg-1_i386.deb"
    else
        XL2TPD_PACKAGE="xl2tpd_1.2.8_dfsg-1_amd64.deb"
    fi
elif which yum &> /dev/null; then
    XL2TPD_PATH="/etc/rc.d/init.d"
    INSTALL_CMD="rpm -i"
    UNINSTALL_CMD="rpm -e"
    BRAS_UP_CONFIG="/etc/ppp/ip-up.local"
    if [ $(uname -m) = "i686" ]; then
        XL2TPD_PACKAGE="xl2tpd-1.3.1-1.fc16.i686.rpm"
    else
        XL2TPD_PACKAGE="xl2tpd-1.3.1-1.fc16.x86_64.rpm"
    fi
elif which zypper &> /dev/null; then
    XL2TPD_PATH="/etc/init.d"
    INSTALL_CMD="rpm -i"
    UNINSTALL_CMD="rpm -e"
    BRAS_UP_CONFIG="/etc/ppp/ip-up.local"
    if [ $(uname -m) = "i686" ]; then
        XL2TPD_PACKAGE="xl2tpd-1.2.4-8.1.3.i586.rpm"
    else
        XL2TPD_PACKAGE="xl2tpd-1.2.4-8.1.3.x86_64.rpm"
    fi
else
    SUPPORTED=0
    BRAS_UP_CONFIG="/etc/ppp/ip-up.d/09-bras.sh"
    echo "It seems that your system doesn't support package of deb or rpm."
    echo "You have to manually install xl2tpd."
fi

if [ -z "$1" ]; then
    BRAS_OUT_ID=my_id
    BRAS_OUT_PASSWORD=my_secret
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

if which xl2tpd &> /dev/null; then
    UNINSTALL_CMD="echo 'You have to manually remove'"
    echo "It seems that the xl2tpd package has been installed."
    if [ -z "$XL2TPD_PATH" ]; then
        echo "Please specify the directory containing xl2tpd daemon, like:"
        echo "/etc/init.d ==> for Ubuntu"
        echo "/etc/rc.d/init.d ==> for Fedora"
        echo "/etc/rc.d ==> for Arch"
    fi
    while [ -z "$XL2TPD_PATH" ]; do
        read -p "xl2tpd path: " XL2TPD_PATH
    done
elif [ "$SUPPORTED" = "1" ]; then
    if which wget &> /dev/null; then
        DOWNCMD="wget --no-proxy"
    elif which curl &> /dev/null; then
        DOWNCMD="curl -O"
    else
        echo "Oh, I don't know how to download the xl2tpd package. :("
        exit 2
    fi
    $DOWNCMD http://bbs.nju.edu.cn/file/S/silverzhao/$XL2TPD_PACKAGE
    $INSTALL_CMD $XL2TPD_PACKAGE
    rm -f $XL2TPD_PACKAGE
fi

if ! which xl2tpd &> /dev/null; then
    echo "Oops! It seems that xl2tpd hasn't been installed. :("
    echo "Please install it first."
    exit 3
fi

XL2TPD_CONFIG_FILE="/etc/xl2tpd/xl2tpd.conf"
BRAS_BIN_DIR="/usr/local/sbin"
BRAS_CONFIG_FILE="/etc/ppp/peers/bras"
BRAS_OUT_CONFIG_FILE="/etc/ppp/peers/bras_out"
BRAS_SECRET_FILE="/etc/ppp/chap-secrets"

mkdir -p $BRAS_BIN_DIR
mkdir -p /etc/ppp/peers

if [ "$SUPPORTED" = "0" ]; then
    mkdir -p /etc/ppp/ip-up.d
fi

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
linkname bras
name $BRAS_ID
noauth
nodefaultroute
EEOOFF

cat > $BRAS_OUT_CONFIG_FILE << EEOOFF
linkname bras_out
name $BRAS_OUT_ID
noauth
nodefaultroute
usepeerdns
mtu 1452
EEOOFF

cat > $BRAS_SECRET_FILE << EEOOFF
# Secrets for authentication using CHAP
# client    server    secret    IP addresses

# for bras in-campus
$BRAS_ID    *    $BRAS_PASSWORD    *

# for bras off-campus
$BRAS_OUT_ID    *    $BRAS_OUT_PASSWORD    *
EEOOFF
chmod 600 $BRAS_SECRET_FILE

sed -e "s:XL2TPD_PATH:$XL2TPD_PATH:" \
    -e "s:BRAS_BIN_DIR:$BRAS_BIN_DIR:" \
    > $BRAS_BIN_DIR/brasup << "EEOOFF"
#!/bin/bash

XL2TPD_PATH/xl2tpd start
if [ -z "$1" ]; then
    GATEWAY=$(ip route | grep "default" | awk '{print $3}')
    if [ -n "$GATEWAY" ]; then
        BRAS_BIN_DIR/bras-route add "$GATEWAY"
    fi
    sh -c 'echo "c bras" > /var/run/xl2tpd/l2tp-control'
    LINKNAME="bras"
else
    sh -c 'echo "c bras_out" > /var/run/xl2tpd/l2tp-control'
    LINKNAME="bras_out"
fi

while ! [ -e /var/run/ppp-$LINKNAME.pid ]; do
    sleep 1
done

IFNAME=$(tail -n 1 /var/run/ppp-$LINKNAME.pid)

if ! ip link show "$IFNAME" &>/dev/null; then
    echo "Bras up failed!"
    echo "Please close it down and wait for a while to try again."
fi
EEOOFF

sed -e "s:XL2TPD_PATH:$XL2TPD_PATH:" \
    -e "s:BRAS_BIN_DIR:$BRAS_BIN_DIR:" \
    > $BRAS_BIN_DIR/brasdown << "EEOOFF"
#!/bin/bash

if [ -z "$1" ]; then
    sh -c 'echo "d bras" > /var/run/xl2tpd/l2tp-control'
    GATEWAY=$(ip route | grep "219.219.112.0" | awk '{print $3}')
    if [ -n "$GATEWAY" ]; then
        BRAS_BIN_DIR/bras-route del "$GATEWAY"
        if ! ip route | grep -q "default"; then
            ip route add default via "$GATEWAY"
        fi
    fi
else
    sh -c 'echo "d bras_out" > /var/run/xl2tpd/l2tp-control'
fi
XL2TPD_PATH/xl2tpd stop
EEOOFF

cat > $BRAS_BIN_DIR/bras-route << "EEOOFF"
#!/bin/bash

ip route $1 58.192.32.0/20 via $2
ip route $1 58.192.48.0/21 via $2
ip route $1 114.212.0.0/16 via $2
ip route $1 172.16.0.0/12 via $2
ip route $1 202.38.2.0/24 via $2
ip route $1 202.38.3.0/24 via $2
ip route $1 202.38.126.160/28 via $2
ip route $1 202.119.32.0/19 via $2
ip route $1 202.127.247.0/24 via $2
ip route $1 210.28.128.0/20 via $2
ip route $1 210.29.240.0/20 via $2
ip route $1 219.219.112.0/20 via $2
EEOOFF

sed -e "s:BRAS_BIN_DIR:$BRAS_BIN_DIR:" > $BRAS_UP_CONFIG << "EEOOFF"
#!/bin/bash

if [ "$LINKNAME" = "bras" ]; then
    ip route replace default dev $IFNAME
elif [ "$LINKNAME" = "bras_out" ]; then
    BRAS_BIN_DIR/bras-route add $IPREMOTE
else
    exit 0
fi
EEOOFF

if ! [ -e /etc/ppp/ip-up ]; then
    cat > /etc/ppp/ip-up << "EEOOFF"
#!/bin/bash
#
# This script is run by pppd when there's a successful ppp connection.
#

# Execute all scripts in /etc/ppp/ip-up.d/
for ipup in /etc/ppp/ip-up.d/*.sh; do
    if [ -x $ipup ]; then
        # Parameters: interface-name tty-device speed local-IP-address
        # remote-IP-address ipparam
        $ipup "$@"
    fi
done
EEOOFF
    chmod +x /etc/ppp/ip-up
fi

cat > $BRAS_BIN_DIR/bras-uninstall << EEOOFF
#!/bin/bash

echo "
##################################
#______Uninstalling Bras...______#
##################################
"
echo "Removing config file..."
rm -f \\
$BRAS_BIN_DIR/brasup \\
$BRAS_BIN_DIR/brasdown \\
$BRAS_BIN_DIR/bras-route \\
$BRAS_BIN_DIR/bras-uninstall \\
$BRAS_CONFIG_FILE \\
$BRAS_OUT_CONFIG_FILE \\
$BRAS_UP_CONFIG \\
$XL2TPD_CONFIG_FILE \\
$BRAS_SECRET_FILE

echo "Removing xl2tpd..."
$UNINSTALL_CMD xl2tpd

echo "Done!"
exit 0
EEOOFF

chmod +x $BRAS_BIN_DIR/brasup
chmod +x $BRAS_BIN_DIR/brasdown
chmod +x $BRAS_BIN_DIR/bras-route
chmod +x $BRAS_BIN_DIR/bras-uninstall
chmod +x $BRAS_UP_CONFIG

if ! grep -q "$BRAS_BIN_DIR" /etc/profile; then
    sed -i "s#^PATH=\"#&$BRAS_BIN_DIR:#" /etc/profile
fi

echo "
##################################
#       Install Completed!       #
#     try 'sudo brasup' now.     #
# if anything wrong, try reboot. #
##################################
"
exit 0

