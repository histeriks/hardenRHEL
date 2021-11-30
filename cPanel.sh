#!/bin/bash
#Server hardening script for cPanel servers

# Make sure only root can run this script
if [ "$(id -u)" != "0" ]; then
   echo -e  "\e[93m This script must be run as root \e[0m"
   exit 1
fi

echo -e "\e[1;36;40m Server Hardening initiated \e[0m"
cd /usr/local/src
rm -f csf* &> /dev/null
echo -e "\e[1;36;40m Installing CSF.....\e[0m"
wget https://download.configserver.com/csf.tgz > /dev/null 2>&1
tar -xzf csf.tgz        > /dev/null 2>&1
cd csf
[ -d /etc/csf  ] && cp -rpf /etc/csf /etc/csf-`date +%d-%m-%y-%T`
sh install.sh  > /dev/null 2>&1

echo -e "\e[1;36;40m Modifying parameters in CSF configuration \e[0m"
sleep 3
sed -i 's/TESTING = "1"/TESTING = "0"/g' /etc/csf/csf.conf
sed -i 's/PT_USERMEM = "512"/PT_USERMEM = "0"/g' /etc/csf/csf.conf
sed -i 's/PT_USERPROC = "10"/PT_USERPROC = "0"/g' /etc/csf/csf.conf
sed -i 's/RESTRICT_SYSLOG = "0"/ RESTRICT_SYSLOG = "3"/g' /etc/csf/csf.conf
sed -i 's/SMTP_BLOCK = "0"/SMTP_BLOCK = "1"/g' /etc/csf/csf.conf
sed -i 's/SYSLOG_CHECK = "0"/SYSLOG_CHECK = "3600"/g' /etc/csf/csf.conf
sed -i 's/LF_SCRIPT_ALERT = "0"/LF_SCRIPT_ALERT = "1"/'  /etc/csf/csf.conf
echo -e "\e[1;36;40m restarting csf \e[0m"
csf -r   > /dev/null 2>&1

# INSTALL MALDET

echo -e " \e[1;36;40m Installing maldet scanner \e[0m"
cd /usr/local/src/
rm -f maldetect* &>/dev/null
wget http://www.rfxn.com/downloads/maldetect-current.tar.gz > /dev/null 2>&1
tar -xzf maldetect-current.tar.gz
cd maldetect-*
sh ./install.sh > /dev/null 2>&1

echo -e "\e[1;36;40m Enabling auto quarantine in maldet configuration \e[0m"
sed -i 's/quarantine_hits="0"/quarantine_hits="1"/g' /usr/local/maldetect/conf.maldet

#INSTALL CLAMAV CPANEL

######  This command tells the system that we want ClamAV to be listed as installed by the local RPM system:

echo -e "\e[1;36;40m INSTALLING CLAMSCAN \e[0m"
/scripts/update_local_rpm_versions --edit target_settings.clamav installed  > /dev/null 2>&1

######  This command is the one responsible for installing the ClamAV RPM on your server:

/scripts/check_cpanel_rpms --fix --targets=clamav   > /dev/null 2>&1

#HOST.CONF TWEAK.  It Prevents IP spoofing and dns poisoning

[ -f /etc/hosts ] && cp -rpf /etc/hosts /etc/hosts-`date +%d-%m-%y-%T`
echo -e "\e[1;36;40m tweaking /etc/hosts \e[0m"
echo -e "order bind,hosts\nmulti on\nnospoof on" > /etc/host.conf

#CMC INSTALLATION
echo -e "\e[1;36;40m Installing cmc \e[0m"
cd /usr/local/src
rm -f cmc* &>/dev/null
wget http://download.configserver.com/cmc.tgz  > /dev/null 2>&1
tar -xzf cmc.tgz  > /dev/null 2>&1
cd cmc
sh install.sh  > /dev/null 2>&1

#SSH useDNS no
sed  -i 's!#UseDNS yes!UseDNS no!g' /etc/ssh/sshd_config
service sshd restart  > /dev/null 2>&1


#SSH PORT CHANGE
check=$(ss -tulpn |grep ssh | awk '{print $5}' | cut -d: -f2)
echo -e "\e[1;36;40m ssh port listening on $check \e[0m"
echo -n -e "\e[1;36;40m Do you wants to change ssh port [y/n]?\e[0m "
port=
while [[ $port = "" ]];
do
echo -n "please enter [y/n]?"
read port
done
if [ $port = 'y' ]
then
cp -rpf /etc/ssh/sshd_config /etc/ssh/sshd_config-`date +%d-%m-%y-%T`
sed -i "s!Port $check!#Port $check!g" /etc/ssh/sshd_config
echo -e " \e[1;36;40m Please enter the port number you wants to change \e[0m"
read sshport
sed -i  "/#Port $check/a\Port $sshport" /etc/ssh/sshd_config
echo -e "\e[1;36;40m allowing the port in csf firewall \e[0m"
grep "TCP_IN =" /etc/csf/csf.conf  |sed  -i "s/\b22\b/&,$sshport/" /etc/csf/csf.conf  > /dev/null 2>&1
csf -r  > /dev/null 2>&1 
service sshd restart  > /dev/null 2>&1
else
echo -e "\e[1;36;40m ssh port not changed. still listening on $check \e[0m"
fi

#RKHUNTER INSTALLATION

echo -e "\e[1;36;40m Installing rkhunter\e[0m"
cd /usr/local/src
rm -rf rkhunter*
wget https://sourceforge.net/projects/rkhunter/files/rkhunter/1.4.4/rkhunter-1.4.4.tar.gz  > /dev/null 2>&1
tar -xzf rkhunter*tar.gz  > /dev/null 2>&1
cd rkhunter*
./installer.sh --layout default --install  > /dev/null 2>&1
/usr/local/bin/rkhunter --update  > /dev/null 2>&1
/usr/local/bin/rkhunter --propupd  > /dev/null 2>&1

#CHKROOTKIT INSTALLATION
echo -e "\e[1;36;40m Installing chkrootkit\e[0m"
cd /usr/local/src
rm -rf chkrootkit*
wget ftp://ftp.pangeia.com.br/pub/seg/pac/chkrootkit.tar.gz  > /dev/null 2>&1
tar -xzf chkrootkit.tar.gz  > /dev/null 2>&1
mkdir /usr/local/chkrootkit  > /dev/null 2>&1
mv chkrootkit*/* /usr/local/chkrootkit    > /dev/null 2>&1
cd /usr/local/chkrootkit  > /dev/null 2>&1
ln -s /usr/local/chkrootkit/chkrootkit /usr/local/bin/chkrootkit  > /dev/null 2>&1
make sense  > /dev/null 2>&1

echo -e "\e[1;36;40m Done.\e[0m"

### Adding local-infile=0 to mysql configuration

echo -e "\e[1;36;40m Adding local-infile=0 to mysql configuration \e[0m"
echo  "local-infile=0" >> /etc/my.cnf
echo -e "\e[1;36;40m restarting mysql \e[0m"
service mysql restart > /dev/null 2>&1

### ADDING DISABLE FUNCTIONS

echo -e "\e[1;36;40m disabling functions in all PHP version  \e[0m"

sed -i 's/disable_function/;&/' /opt/cpanel/ea-php*/root/etc/php.ini

sed -i "/;disable_function/a\disable_functions = show_source, system, shell_exec, passthru, exec, phpinfo, popen, proc_open" /opt/cpanel/ea-php*/root/etc/php.ini

[ -d /opt/alt/php56 ] && sed -i 's/disable_function/;&/' /opt/alt/php*/etc/php.ini

[ -d /opt/alt/php56 ] && sed -i "/;disable_function/a\disable_functions = show_source, system, shell_exec, passthru, exec, phpinfo, popen, proc_open" /opt/alt/php*/etc/php.ini



## DISABLEING COMPLIERS

echo -e " \e[1;36;40m Disabling compliers \e[0m "

/scripts/compilers off


### TWEAKING SETTINGS 

echo -e  '\e[1;36;40m TWEAK SETTINGS HARDENING \e[0m'

cp -rpf /var/cpanel/cpanel.config /var/cpanel/cpanel.config-`date +%d-%m-%y-%T`
sed -i 's/cgihidepass=0/cgihidepass=1/' /var/cpanel/cpanel.config
sed -i 's/proxysubdomains=1/proxysubdomains=0/' /var/cpanel/cpanel.config
sed -i 's/referrerblanksafety=0/referrerblanksafety=1/' /var/cpanel/cpanel.config
sed -i 's/referrersafety=0/referrersafety=1/' /var/cpanel/cpanel.config
sed -i 's/skipboxtrapper=0/skipboxtrapper=1/'  /var/cpanel/cpanel.config
sed -i 's/proxysubdomains=1/proxysubdomains=0/' /var/cpanel/cpanel.config
sed -i 's/maxemailsperhour=undef/maxemailsperhour=150/' /var/cpanel/cpanel.config
sed -i 's/resetpass=1/resetpass=0/' /var/cpanel/cpanel.config
sed -i 's/resetpass_sub=1/resetpass_sub=0/' /var/cpanel/cpanel.config

#Kernel update check
con_check()
{
if [[ "$?" -eq 0 ]]
                                                then
                                                echo -e "\e[1;36;40m grub entry succssfully updated. Server is ready for reboot \e[0m"
                                                else
                                                echo -e "\e[1;36;40m  updated kernel not found in grub. Kindly review grub entry \e[0m"
                                                fi
}


echo -e "\e[1;36;40m checking for kernel update \e[0m"
cl=$(yum list kernel |grep -A2 Available | awk '{print $2}' |grep -v Packages |cut -d: -f2)
ker_check=$(yum list kernel |grep -A2 Available | awk '{print $2}' |grep -v Packages)
yum list kernel |grep -i Available
if [[ "$?" -eq 0 ]]
then
     echo -e "\e[1;36;40m kernel update available \e[0m"
     echo -e "\e[1;36;40m Do you want to update kernel [y/n]?"

get=
while [[ $get = "" ]];
do
echo -n "please enter [y/n]?"
read get
done
     if [ $get = 'y' ]
            then
            echo -e "\e[1;36;40m kernel update is in progress..... \e[0m"
            yum update kernel -y > /dev/null 2>&1
            echo -e "kernel update completed successfully"
            release=$(cat /etc/redhat-release  |grep -E "Cent|Cloud")
                  if [[ $release == *"Cent"* ]]
                  then
                            ver_check=$(cat /etc/redhat-release  |grep -E "6.|7.")
                                if [[ $ver_check == *"6."* ]]
				                then
                                grep '^[[:space:]]*kernel' /boot/grub/grub.conf |grep $ker_check > /dev/null 2>&1
				con_check
                                else [[ $ver_check == *"7"* ]]
                  		            awk -F\' '$1=="menuentry " {print i++ " : " $2}' /etc/grub2.cfg | grep $ker_check  > /dev/null 2>&1
	
