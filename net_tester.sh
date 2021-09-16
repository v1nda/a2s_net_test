#!/bin/sh

interface='enp3s0'

echo 'Network settings:'

echo -e '\t> dev\t\t'$interface

interface_addr=`ifconfig $interface | grep 'inet ' | awk {'print $2'}`
interface_mask=`ifconfig $interface | grep 'inet ' | awk {'print $4'}`

echo -e '\t> ipaddr\t'$interface_addr
echo -e '\t> netmask\t'$interface_mask

function net_devs {
        echo -e '\n[network devs]\n'

        while read net
        do
                echo -e '> subnet '$net
                hosts_file='src/net_'$net

                while read host
                do
                        host_name=`echo $host | cut -d ':' -f1`
                        host_addr=`echo $host | cut -d ':' -f2`
                        host_web=`echo $host | cut -d ':' -f3`

                        echo -e '\t\t# '$host_name

                        ping_result=`ping $host_addr -c 3 | grep 'transmitted'`
                        ping_result_percent=`echo $ping_result | awk {'print $6'}`
                        echo -e '['$ping_result_percent'] ping\t'$host_addr'\t('$ping_result')'

                        web_result=`curl -ILsko /dev/null -m 5 -w "%{http_code}" $host_web://$host_addr`
                        if [[ $web_result != 000 ]]
                        then
                                web_result_str='+'
                        else
                                web_result_str='-'
                        fi
                        echo -e '['$web_result_str'] web\t\t'$host_addr'\t(HTTP code '$web_result')'

                done < $hosts_file
        done < src/nets
}

function dns {
        dnss=(
                '192.168.14.220'
                '192.168.14.20'
                '192.168.50.220'
                '192.168.50.20'
                '208.67.222.222'
        )
        sites=(
                'yandex.ru'
                'google.com'
                'mail.ru'
                'wikipedia.org'
                'youtube.com'
        )

        echo -e '\n[check dns servers]\n'

        for (( i = 0; i < 5; i++ ))
        do
                result=`nslookup -timeout=1 ${sites[$i]} ${dnss[$i]}`
                dns_addr=`echo $result | awk {'gsub("#", ":"); print $4'}`
                site_addr=`echo $result | egrep -o '[0-9]+.[0-9]+.[0-9]+.[0-9]+'`
                site_addr=`echo $site_addr | cut -d ' ' -f3`

                if [ -n $site_addr ]
                then
                        dns_result_str='+'
                else
                        dns_result_str='-'
                fi

                echo -e '['$dns_result_str']\t\t'$dns_addr'\t('${sites[$i]}', '`echo $site_addr | grep '' -m 1`')'
        done

        echo -e '\n[local dns names resolution]\n'

        while read name
        do
                result=`nslookup -timeout=1 $name ${dnss[0]}`
                addr=`echo $result | egrep -o '[0-9]+.[0-9]+.[0-9]+.[0-9]+'`
                addr=`echo $addr | cut -d ' ' -f3`

                if [ -n $addr ]
                then
                        addr_result_str='+'
                else
                        addr_result_str='-'
                fi

                echo -e '['$addr_result_str']\t\t'$addr'\t'$name
        done < src/dns_names
}

function servers {

        echo -e '\n[checking servers]'

        for server in src/servers/*
        do
                echo -e '\n\t> '`echo $server | cut -d '/' -f3`'\n'

                while read str
                do
                        service=`echo $str | cut -d ':' -f1`
                        
                        case $service in
                                ip)
                                        ip_addr=`echo $str | cut -d ':' -f2`
                                        ;;
                                ssh)
                                        user=`echo $str | cut -d ':' -f2 | cut -d '.' -f1`
                                        port=`echo $str | cut -d ':' -f2 | cut -d '.' -f2`

                                        start=$(date +%s)
                                        ssh_res=`timeout 5 ssh -tt -o BatchMode='yes' $user@$ip_addr`
                                        end=$(date +%s)
                                        diff=$(( $end - $start ))

                                        if [[ $diff < 5 ]]
                                        then
                                                ssh_state='+'
                                        else
                                                ssh_state='-'
                                        fi

                                        echo -e '['$ssh_state'] ssh\t\t'$user@$ip_addr
                                        ;;
                                web)
                                        proto=`echo $str | cut -d ':' -f2 | cut -d ',' -f1`
                                        name=`echo $str | cut -d ':' -f2 | cut -d ',' -f2 | cut -d '.' -f1`
                                        port=`echo $str | cut -d ':' -f2 | cut -d ',' -f2 | cut -d '.' -f2`

                                        web_res=`curl -ILsko /dev/null -m 5 -w "%{http_code}" $proto://$ip_addr:$port`
                                        if [[ $web_res != 000 ]]
                                        then
                                                web_state='+'
                                        else
                                                web_state='-'
                                        fi

                                        echo -e '['$web_state'] web\t\t'$ip_addr:$port'\t'$name
                                        ;;
                                smb)
                                        res=`timeout 5 smbclient //192.168.14.20/eplan -U ADVANS\\dvinogradov 53gswnf5`
                                        res=`echo $res | grep 'smb'`
                                        echo $res
                                        ;;
                                *)
                                        echo 'unknow service'
                                        ;;
                        esac

                done < $server

        done < src/dns_names
}

net_devs
dns
servers