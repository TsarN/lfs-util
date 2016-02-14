#!/bin/bash
function usage {
    echo "Usage: service <service name> <status|start|stop|restart|reload|enable|disable|remove>"
}

if [ $# -eq 2 ]; then
    if [ $2 = "start" ] || [ $2 = "stop" ] || [ $2 = "restart" ] || [ $2 = "status" ] || [ $2 = "reload" ]; then
        if [ -e "/etc/init.d/$1" ]; then
            /etc/init.d/$1 $2
        else
            echo "No such service"
            usage
        fi
    elif [ $2 = "enable" ] || [ $2 = "disable" ] || [ $2 = "remove" ]; then
        if [ -e "/etc/init.d/$1" ] || [ $2 = "enable" ]; then
            pushd .
            cd /usr/share/bootscripts
            if [ $2 = "enable" ]; then
                make "install-$1"
            elif [ $2 = "remove" ]; then
                make "uninstall-$1"
            else
                find /etc/rc.d | grep "[KS][0-9][0-9]$1$" | xargs rm -v    
            fi
            popd
        else
            echo "No such service"
            usage        
        fi
    else
        echo "Invalid invokation"
        usage
    fi
else
    usage
fi
