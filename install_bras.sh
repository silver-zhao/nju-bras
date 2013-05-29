#!/bin/bash

read_user_info()
{

}

bras_route()
{
	if [ "$1"="add" -o "$1"="del" ]; then
		if [ -n "$2" ]; then
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
		fi
	else
		echo "$0 { add | del } <gateway>"
	fi
}

bras_start()
{
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
}

bras_stop()
{
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
}

bras_uninstall()
{
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
}

bras_help()
{
echo "
Usage: bras [-o] COMMAND

OPTION:
-o			for bras off-campus

COMMAND:
up			start bras
down		stop bras
new			a new user, will save the new user's name and password
login		a temporary user, will not save the new user's name and password
uninstall	uninstall bras
help		show this help information
"
}

BRAS_SECRET_FILE=/etc/xl2tpd/l2tp-secrets.bras
BRAS_OUT_SECRET_FILE=/etc/xl2tpd/l2tp-secrets.bras_out


cat > $XL2TPD_CONFIG_FILE << EEOOFF
[lac bras]
lns = 172.21.100.100
pppoptfile = $BRAS_CONFIG_FILE
auth file = $BRAS_SECRET_FILE
redial = yes
redial timeout = 10
max redial = 3

[lac bras_out]
lns = 218.94.142.114
pppoptfile = $BRAS_OUT_CONFIG_FILE
auth file=$BRAS_OUT_SECRET_FILE
redial = yes
redial timeout = 10
max redial = 3
EEOOFF


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
