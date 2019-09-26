# weedog-ZM

WeeDog is built using scripts written by wiak and detailed information and
documentation is here -> [Puppy Linux Forum](http://www.murga-linux.com/puppy/viewtopic.php?t=116212)

The firstrib00-XX.plug files are designed to construct a simple desktop with several applications
included. Using JWM and ROX --pinboard along with xlunch provide the window manager, file manager
and xlunch for the menu system. Both plugs are designed for installing ZoneMinder via the
build_ZM.sh script.


The **build_ZM.sh** script creates a LHMP server. Hiawatha, mariadb, PHP 7+ PERL PYTHON.
ZoneMinder source code is cloned into /root/Build. All the dependencies and requirements are
downloaded and installed, followed by the cmake, make, make install commands which compile, build then installs zoneminder.  The script can also be used as a guide or each step can
be manually done.

ZM (zoneminder) can be updated/upgraded by opening a terminal in /root/Build/zoneminder then using `git pull` and using the cmake configuration ->



    cmake CMAKE_INSTALL_PREFIX=/usr -DCMAKE_SKIP_RPATH=ON -DCMAKE_VERBOSE_MAKEFILE=OFF -DCMAKE_COLOR_MAKEFILE=ON -DZM_RUNDIR=/var/run/zm -DZM_SOCKDIR=/var/run/zm -DZM_TMPDIR=/var/tmp/zm -DZM_LOGDIR=/var/log/zm -DZM_WEBDIR=/usr/share/zoneminder/www -DZM_CONTENTDIR=/var/cache/zoneminder -DZM_CGIDIR=/usr/lib/zoneminder/cgi-bin -DZM_CACHEDIR=/var/cache/zoneminder/cache -DZM_WEB_USER=www-data -DZM_WEB_GROUP=www-data -DCMAKE_INSTALL_SYSCONFDIR=etc/zm -DZM_CONFIG_DIR=/etc/zm -DCMAKE_BUILD_TYPE=Release .

     make
     make install
     zmupdate.pl





## run the scripts

The 1st example uses the firstrib00-NoX.plug which creates a minimal command line operating
system with no X server or GUI programs based on Void Linux. This version  has mc as the file manager and after runnning the build_ZM script and starting **dropbear**, remote control ssh
can make the machine a headless ZM server.

Also a very basic place to start building for a specific function or creating a new desktop.
Timezone is set to UTC during the build process.

To start the creation of a WeeDog set up a frugal install. In the boot parition or USB drive
that is formated for a Linux file system. 

Make a directory that in this example will be /mnt/sda1/weedog-ZM and copy the following
files into it.
 
   - build_firstrib_rootfs_103.sh
   - build_weedog_initramfs05_s203.sh
   - firstrib00-NoX.plug
   - build_ZM.sh


The build_ZM.sh script will be run after the first boot and OS is up and running and is not
needed in these steps.

start a terminal in /mnt/sda1/weedog-ZM and run the scripts individually or write a small script 
that will automate the steps.

    #!/bin/sh
    ./build_firstrib_rootfs_103.sh void rolling amd64 firstrib00-NoX.plug
    ./build_weedog_initramfs05_s203.sh void


or run each script individually.

this is an example of a Grub4Dos entry for menu.lst.
Change the uuid to match the parition weedog-ZM is installed on -> 

    title weedog-ZM (Void Linux)
        uuid 1ef03b67-ebf1-447a-808c-eaa32169e89a
        kernel /weedog-ZM/vmlinuz-5.2.17_1  net.ifnames=0 usbwait=4 bootfrom=/mnt/sdb1/weedog-ZM
        initrd /weedog-ZM/initramfs05.gz


Once the weedog-ZM is booted login

   - user = root
   - password = root

start `mc` and copy the build_ZM.sh script from /mnt/your-device/weedog-ZM to /root

     chmod +x /root/build_ZM.sh
     /root/build_ZM.sh

the script will run until the message appears

  >done setting up ZoneMinder and the LHMP....

in the shell run

    hiawatha 
    zmpkg.pl

Timezone in /etc/php.ini and the system clock MUST match. 

  to start the servers

     hiawatha
     mysqld --user=root &
     zmpkg.pl start

  to stop the servers

     zmpkg.pl stop
     killall hiawatha
     killall mysqld

if there is difficulty starting mysqld after a reboot check and make sure the
directory **/run/mysqld** exists. If it does not exist create it and then start 

      mysqld --user=root &
