#!/bin/bash

# Geek Desktop v0.1-rc146
# Copyright (c) 2004 - Reinaldo Carvalho
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA.

### Functions ###

grava_log () {
	if [ "$LOG" ] ; then
		date +"%b %d %X $HOSTNAME geek-installer.sh[$$]: $1" >> $LOG
	else
		echo "Erro: LOG PATH nao definido".
		exit
	fi
}

help () {

	echo
	echo "Usage: $0 [OPTION]"
	echo
	echo '	-V,  --version		Informa a versao do programa.'
	echo '	-v,  --verbose		Mostra mensagens do apt-get.'
	echo '	-c,  --checksum		Checa integridade dos arquivos.'
	echo '	-d,  --debug		Aguarda um Enter a cada passo.'
	echo
	echo 'Email para bugs: rei@nautilus.com.br .'
	echo "Por favor, inclua 'Geek Desktop' no assunto."
}

switch_debconf () {

        case "$1" in
		--to-critical)
			sed -e 's/Value: medium/Value: critical/g' /var/cache/debconf/config.dat > /tmp/.geek.debconf
			mv /tmp/.geek.debconf /var/cache/debconf/config.dat
			grava_log 'Debconf setado para critical.'
		;;
		--to-medium)
			sed -e 's/Value: critical/Value: medium/g' /var/cache/debconf/config.dat > /tmp/.geek.debconf
			mv /tmp/.geek.debconf /var/cache/debconf/config.dat
			grava_log 'Debconf setado para medium.'
		;;
		*)
			echo 'Erro: Uso incorreto da funcao switch_debconf'
			exit
		;;
	esac

}

geek_path () {

	paths="$(pwd) /cdrom $(mount | cut -f 3 -d " ")"
	basefiles="/geek-base /geek-debs /geek-inst /geek-man /Packages.gz"

 	for i in $paths ; do
		for j in $basefiles ; do
			if ! [ -e "$i$j" ] ; then
				Error='1'
			fi
		done
		if [ -z "$Error" ] ; then
			BASE_PATH="$i"
			return 0
		else
			unset Error
		fi
	done

	echo 'Erro: Nao foi possivel localizar os arquivos de instalação.'
	exit

}

newlilo () {

	vmlinuz () {
		if ! [ -e /boot/debian-bootscreen-woody.rle.bmp ] ; then
			cd /boot
			tar xzf $BASE_PATH/geek-base/debian-bootscreen-0.31.tar.gz ./debian-bootscreen-woody.rle.bmp
			chown root.root /boot/debian-bootscreen-woody.rle.bmp
		fi
		grava_log "Configurando LILO."
		ROOT=$(cat /etc/lilo.conf | grep -e '^root=/dev' | cut -f3 -d '/')
		BOOT=$(cat /etc/lilo.conf | grep -e '^boot=/dev' | cut -f3 -d '/')
		sed -e "s/ROOT/$ROOT/g" "$BASE_PATH"/geek-inst/lilo.conf > /tmp/.geek.lilo
		sed -e "s/BOOT/$BOOT/g" /tmp/.geek.lilo > /etc/lilo.conf
	
		for i in $(/bin/ls /boot/vmlinuz-* | grep -v ".old" | sort -r | uniq) ; do
			if [ -e "$i" ] ; then
				j=$(echo $i | cut -f3 -d '/' | cut -f2 -d '-' | cut -f1 -d '-')
				if [ -z "$default" ] ; then
					echo "default=Linux_$j" >> /etc/lilo.conf
					default=1
				fi
				echo >> /etc/lilo.conf
				echo image=$i >> /etc/lilo.conf
				echo "	label=Linux_$j" >> /etc/lilo.conf
				if [ "$j" = '2.4.27' ] ; then
					echo "	append=\"splash=silent\"" >> /etc/lilo.conf
					echo "	initrd=/boot/initrd.img-2.4.27" >> /etc/lilo.conf
				fi
				echo "	vga=0x301" >> /etc/lilo.conf
				echo "	read-only" >> /etc/lilo.conf
			fi
		done

		echo >> /etc/lilo.conf

	}

	ms () {
		unset devices
		for i in hda hdb hdc hdd hde hdf hdg hdh sda sdb sdc sdd ; do
			if [ -e /proc/*/$i/geometry ] ; then
				dev="/dev/$i"
				devices="$devices $dev"
			fi
		done
		for i in $devices ; do
			for j in $(fdisk -l $i | grep -e FAT -e NTFS | cut -f1 -d " " 2> /dev/null); do
				echo "other=$j" >> /etc/lilo.conf
				dev=$(echo $j | cut -f3 -d '/')
				echo "	label=Win_$dev" >> /etc/lilo.conf
				echo >> /etc/lilo.conf
				if [ "$1" = "basic" ] ; then
					return 0
				fi
			done
		done
	}

	x=1x
	false
	while [ "$?" != '0' ] ; do
		grava_log "Gravando LILO. $x"
		vmlinuz
		case "$x" in
			1x)
				ms
				x=2x
			;; 
			2x)
				ms basic
				x=3x
			;;
			3x)
				x=4x
			;;
			4x)
				echo 'Erro: O Lilo nao pode ser gravado corretamente.'
				exit 0
			;;
		esac
		lilo > /dev/null 2>&1
	done

}

getmd5 () {

	cd $BASE_PATH
	cat /dev/null > /tmp/geek.tmp
	for i in $(find ./ | grep -v './geek-inst/geek.md5' | sort) ; do
		if ! [ -d "$i" ] ; then
			FILE=$(basename $i)
			MD5=$(md5sum "$i" | cut -f1 -d ' ')
			if (cat ./geek-inst/geek.md5 | grep "$MD5  $i" > /dev/null 2>&1) ; then
				echo "Checksum  [ OK ]  $FILE."
			else
				echo "Checksum  [ERRO]  $FILE."
				ERRO=1
			fi
		fi
	done

	if [ "$ERRO" = '1' ] ; then
		echo 'Erro: arquivos corrompidos.'
		exit
	fi

} 

gmkdir () {

	if ! [ -d "$1/" ] ; then
		mkdir "$1"
	fi

}

karamba () {

	cp "$BASE_PATH"/geek-inst/geek-"$1".rc /etc/skel/.superkaramba/geek.rc
	for i in /home/* ; do
		if ! [ "$i" = '/home/lost+found' ] ; then
			cp "$BASE_PATH"/geek-inst/geek-"$1".rc $i/.superkaramba/geek.rc
		fi
	done

}

debug () {

	if [ "$DEBUG" = 'on' ] ; then
		read -p 'Debug: Deseja Continuar? [Y/n] ' -n 1 YESNO
		if [ "$YESNO" = 'n' -o "$YESNO" = 'N' ] ; then
			echo
			exit
		else
			clear
		fi
	fi

}


### Inicialização ###

LOG='/var/log/geek-installer.log'
VERSION='Geek Desktop v0.1-rc146'
grava_log "== $VERSION =="
grava_log 'Inicializando variaveis.'
geek_path
TITLE="Geek Desktop Installer                                              $(echo $VERSION | cut -f3 -d ' ')"
COLS=$( tput cols )
LINES=$( tput lines )
KERNEL_VERSION=$(uname -rsm)
rm /tmp/.geek* > /dev/null 2>&1
touch /etc/exim/exim.conf
touch /etc/resolv.conf
PidOf=$(echo $$)
gmkdir /root/geek

echo "$VERSION"

for i in $@ ; do
	case "$i" in
		-V|--version)
			grava_log 'Argv: Versao.'
			exit
		;;
		-v|--verbose)
			grava_log 'Argv: Verbose Mode.'
			VERBOSE='on'
		;;
		-h|--help)
			grava_log 'Argv: Help.'
			help
			exit
		;;
		-c|--checksum)
			grava_log 'Argv: Checksum.'
			CHECKSUM='on'
		;;
		-d|--debug)
			grava_log 'Argv: Debug Mode.'
			DEBUG='on'
		;;
		*)
			PARAM="$PARAM $i"
		;;
	esac
done

if ! [ -z "$PARAM" ] ; then
	grava_log "Erro: Parametros invalidos [$PARAM ]"
	echo "Erro: Parametros invalidos [$PARAM ]"
	help
	exit
fi

if [ "$CHECKSUM" = 'on' ] ; then
	getmd5
fi

if [ "$UID" != '0' ] ; then
	echo 'Erro: Voce precisar executar como root.'
	exit
fi

if [ "$COLS" -lt '80' ] ; then
	grava_log 'Erro: Número de colunas menor que 80.'
	echo 'Erro: O Terminal deve ser pelo menos de 80x30.'
	exit
fi

if [ "$LINES" -lt '30' ] ; then
	grava_log 'Erro: Número de linhas menor que 30.'
	echo 'Erro: O Terminal deve ser pelo menos de 80x30.'
	exit
fi		

if ! [ -x /usr/bin/dialog ] ; then
	echo "Instalando Componentes..."
	if [ -e "$BASE_PATH/geek-debs/debian-woody/dialog_0.9a-20020309a-1_i386.deb" ] ; then
		dpkg -i --force-all "$BASE_PATH/geek-debs/debian-woody/dialog_0.9a-20020309a-1_i386.deb" > /dev/null 2>&1
	else
		grava_log 'Erro: Dialog Package não encontrado.'
		echo 'Erro: Dialog Package não encontrado.'
		exit
	fi
fi

	debug

switch_debconf --to-critical

### Texto de Apresentação ###

	grava_log "Apresentação."
	dialog --no-shadow --backtitle "$TITLE" \
		--begin   2  1 --infobox 'Anterior..: ---             \nAtual.....: Apresentação.                                      [01 de 10]\nPróximo...: Licença do Software.          \n' 5 78 \
		--and-widget \
		--begin   7  1 --ok-label Ok --title "Apresentação" --textbox "$BASE_PATH"/geek-inst/Inicio.txt 22 78
	debug

### Licença do Software ###

	dialog --no-shadow --backtitle "$TITLE" \
		--begin   2  1 --infobox 'Anterior..: Apresentação.    \nAtual.....: Licença do Software.                               [02 de 10]\nPróximo...: Kernel Linux.   \n' 5 78 \
		--and-widget \
		--begin   7  1 --title "Licença do Software" --textbox "$BASE_PATH"/geek-inst/License_gpl.txt 22 78 \
		--and-widget \
		--shadow --yesno '\n  Você aceita os Termos da Licença?' 7 40


	if [ "$?" = '1' ] ; then
		grava_log "Licença Recusada."
		dialog --no-shadow --backtitle "$TITLE" \
			--begin   2  1 --infobox 'Anterior..: Apresentação.    \nAtual.....: Licença do Software.                               [03 de 03]\nPróximo...: Sair.   \n' 5 78 \
			--and-widget \
			--begin   12  15 --shadow --ok-label Sair --msgbox '\n              Licença Recusada.\n' 7 50
		switch_debconf --to-medium
		exit
	fi

	grava_log "Licença Aceita."

### Kernel Linux ###

Loop0='0'
while [ "$Loop0" = '0' ] ; do
	Loop0='1'
	dialog --no-shadow --backtitle "$TITLE" \
		--begin   2  1 --infobox 'Anterior..: Licença do Software.\nAtual.....: Kernel Linux.                                      [03 de 10]\nPróximo...: Seleção de Pacotes Debian Woody Backports.\n' 5 78 \
		--and-widget \
		--begin   7  1 --infobox 'Nota: Selecione o Kernel Linux adequado ao seu sistema, \n      Em caso de dúvidas, escolha a opção "Kernel x86"' 4 78 \
		--and-widget \
		--begin   11 1 --title "Kernel Linux" --no-cancel --ok-label Ok --stdout --radiolist 'Selecione o Kernel Linux apropriado:' 18 78 8 \
			1A 'Kernel Otimizado para K7 / Duron / Atlhon / Atlhon XP'     off    \
			1B 'Kernel Otimizado para K6 / K6 II / K6 III'                 off    \
			1C 'Kernel Otimizado para Pentium 4'                           off    \
			1D 'Kernel Otimizado para Pentium 3 / Coppermine'              off    \
			1E 'Kernel Otimizado para Pentium 2 / Pentium Pro / Celeron'   off    \
			1F 'Kernel x86: 386, 486, 586, Pentium MMX, VIA C3, ...'       off    \
			1G 'Compilar Kernel Manualmente (make menuconfig)'             off    \
			1H "Continuar com Kernel atual  ($KERNEL_VERSION)"             on     > /tmp/.geek.kernel

	KERNEL=$(cat /tmp/.geek.kernel)

	case "$KERNEL" in
		1A)
			KERNEL='atlhon'
			grava_log "Escolhido Kernel Atlhon."
		;;
		1B)
			KERNEL='k6'
			grava_log "Escolhido Kernel K6."
		;;
		1C)
			KERNEL='p4'
			grava_log "Escolhido Kernel Pentium 4."
		;;
		1D)
			KERNEL='p3'
			grava_log "Escolhido Kernel Pentium 3."
		;;
		1E)
			KERNEL='p2'
			grava_log "Escolhido Kernel Pentium 2."
		;;
		1F)
			KERNEL='i386'
			grava_log "Escolhido Kernel i386."
		;;
		1G)
			grava_log "Iniciando Compilação."
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Licença do Software.    \nAtual.....: Kernel Linux.                                      [03 de 04]\nPróximo...: Compilando.  \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n         Descompactando Linux 2.4.27...  \n' 5 50
			echo "deb file:$BASE_PATH ./" > /etc/apt/sources.list
			apt-get update > /dev/null 2>&1
			apt-get -yqq install make gcc libncurses5-dev bzip2 patch > /dev/null 2>&1
			cd /usr/src
			cp "$BASE_PATH"/geek-base/linux-2.4.27.tar.gz .
			tar xzf linux-2.4.27.tar.gz
			rm linux > /dev/null 2>&1
			rm kernel-source-2.4.27 > /dev/null 2>&1
			ln -s linux-2.4.27 linux
			ln -s linux-2.4.27 kernel-source-2.4.27
			cd /usr/src/linux
			patch -p1 < "$BASE_PATH"/geek-base/bootsplash-3.0.7-2.4.26.diff > /dev/null 2>&1
			cp "$BASE_PATH"/geek-inst/config-2.4.27 .config
			Loop1='0'
			while [ "$Loop1" = '0' ] ; do
				Loop1='1'
				make menuconfig
				dialog --no-shadow --backtitle "$TITLE" \
					--begin   2  1 --infobox 'Anterior..: Kernel Linux.    \nAtual.....: Compilando.                                        [04 de 04]\nPróximo...: Reiniciar.  \n' 5 78 \
					--and-widget \
					--begin   12  15 --shadow --infobox '\n      Compilando Linux 2.4.27. (make dep)  \n' 5 50
				grava_log "Compilando... make dep"
				make dep > /dev/null 2>&1
				dialog --no-shadow --backtitle "$TITLE" \
					--begin   2  1 --infobox 'Anterior..: Kernel Linux.    \nAtual.....: Compilando.                                        [04 de 04]\nPróximo...: Reiniciar.  \n' 5 78 \
					--and-widget \
					--begin   12  15 --shadow --infobox '\n      Compilando Linux 2.4.27. (make clean)  \n' 5 50
				grava_log "Compilando... make clean"
				make clean > /dev/null 2>&1
				dialog --no-shadow --backtitle "$TITLE" \
					--begin   2  1 --infobox 'Anterior..: Kernel Linux.    \nAtual.....: Compilando.                                        [04 de 04]\nPróximo...: Reiniciar.  \n' 5 78 \
					--and-widget \
					--begin   12  15 --shadow --infobox '\n    Compilando Linux 2.4.27. (make modules)  \n' 5 50
				grava_log "Compilando... make modules"
				make modules > /dev/null 2>&1
				rm -rf /lib/modules/2.4.27 > /dev/null 2>&1
				make modules_install > /dev/null 2>&1
				cd /lib/modules/2.4.27
				rm build > /dev/null 2>&1
				ln -s /usr/src/linux-2.4.27 build
				cd /usr/src/linux
				dialog --no-shadow --backtitle "$TITLE" \
					--begin   2  1 --infobox 'Anterior..: Kernel Linux.    \nAtual.....: Compilando.                                        [04 de 04]\nPróximo...: Reiniciar.  \n' 5 78 \
					--and-widget \
					--begin   12  15 --shadow --infobox '\n    Compilando Linux 2.4.27. (make bzImage)  \n' 5 50
				grava_log "Compilando... make bzImage"
				make bzImage > /dev/null 2>&1
				if [ -e "/usr/src/linux/arch/i386/boot/bzImage" ] ; then
					KERNEL='Compilado'
					grava_log "Kernel Compilado com Sucesso."
				else
					grava_log "Erro: bzImage nao gerou imagem."
					dialog --no-shadow --backtitle "$TITLE" \
						--begin   2  1 --infobox 'Anterior..: Kernel Linux.    \nAtual.....: Compilando.                                        [04 de 04]\nPróximo...: Reiniciar.  \n' 5 78 \
						--and-widget \
						--begin   12  15 --shadow --yesno '\n         Ocorreu um erro na compilação.  \n  Selecionar novamente os itens do Kernel?  \n' 7 50
					if [ "$?" = '0' ] ; then
						Loop1='0'
						grava_log "Erro: voltando ao make menuconfig."
					else
						Loop0='0'
						grava_log "Erro: voltando ao menu Kernel Linux."
					fi
				fi
			done
		;;
		1H)
			unset KERNEL
			grava_log "Continuando com Kernel Atual - $KERNEL_VERSION."
		;;
		*)
			unset KERNEL
			grava_log "Continuando com Kernel Atual - $KERNEL_VERSION."
		;;
	esac

done



	if [ "$KERNEL" ] ; then
		if [ "$KERNEL" = 'Compilado' ] ; then
			grava_log "Instalando Kernel Compilado."
			cp /usr/src/linux/arch/i386/boot/bzImage /boot/vmlinuz-2.4.27
			cp /usr/src/linux/System.map /boot/System.map-2.4.27
			cp /usr/src/linux/.config /boot/config-2.4.27
		else
			grava_log "Instalando Kernel Pré-Compilado - $KERNEL."
			dpkg -x "$BASE_PATH"/geek-debs/kernel_2.4.27/kernel-image-2.4.27_1.00."$KERNEL"_i386.deb /tmp/.geek.kernel.deb > /dev/null 2>&1
			mv /tmp/.geek.kernel.deb/boot/* /boot > /dev/null 2>&1
			rm -rf /lib/modules/2.4.27 > /dev/null 2>&1
			mv /tmp/.geek.kernel.deb/lib/modules/* /lib/modules > /dev/null 2>&1
			rm -rf /usr/src/kernel-headers-2.4.27 > /dev/null 2>&1
			cd /usr/src
			dpkg -x "$BASE_PATH"/geek-debs/kernel_2.4.27/kernel-headers-2.4.27_1.00."$KERNEL"_i386.deb /tmp/.geek.headers > /dev/null 2>&1
			mv /tmp/.geek.headers/usr/src/kernel-headers-2.4.27 .
			rm linux > /dev/null 2>&1
			ln -s kernel-headers-2.4.27 linux
			cd /lib/modules/2.4.27
			rm build > /dev/null 2>&1
			ln -s /usr/src/kernel-headers-2.4.27 build
		fi
			dpkg -x "$BASE_PATH"/geek-base/bootsplash_3.1-6_i386.deb /tmp/.geek.splash
			mv -f /tmp/.geek.splash/sbin/* /sbin
			mv -f /tmp/.geek.splash/usr/sbin/* /usr/sbin
			mv -f /tmp/.geek.splash/etc/init.d/* /etc/init.d/
			mv -f /tmp/.geek.splash/etc/default/* /etc/default/
			gmkdir /etc/bootsplash
			gmkdir /etc/bootsplash/themes
			cd /etc/bootsplash/themes
			tar xzf "$BASE_PATH"/geek-base/theme-bootsplash.tar.gz
			rm default current > /dev/null 2>&1
			ln -s Debian default
			ln -s Debian current
			update-rc.d bootsplash defaults > /dev/null 2>&1
			splash -s -f /etc/bootsplash/themes/Debian/config/bootsplash-1024x768.cfg > /boot/initrd.img-2.4.27
			cd /dev
			rm cdrom > /dev/null 2>&1
			ln -s scd0 cdrom
			rm cdrom2 > /dev/null 2>&1
			ln -s scd1 cdrom2
			rm /vmlinuz > /dev/null 2>&1
			newlilo
			cat /dev/null > /etc/modules
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Kernel Linux    \nAtual.....: Reiniciar.                                         [04 de 04]\nPróximo...: ---  \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n              Kernel Instalado.\n        Tecle ENTER para reiniciar...\n\n      Após reiniciar, inicie novamente a\n        instalação do Geek Desktop' 9 50
			grava_log "Reiniciando."
			cp -a "$BASE_PATH"/geek-inst/sources.list /etc/apt/sources.list
			switch_debconf --to-medium
			read
			reboot
			exit
	fi

	debug

### Seleção de Pacotes Debian ###

	dialog --no-shadow --backtitle "$TITLE" \
		--begin   2  1 --infobox 'Anterior..: Kernel Linux.    \nAtual.....: Seleção de Pacotes Debian Woody Backports.         [04 de 10]\nPróximo...: Instalação de Pacotes Debian Woody Backports.   \n' 5 78 \
		--and-widget \
		--begin   7  1 --title "Seleção de Programas" --ok-label "Instalar" --cancel-label "Pular Etapa" --separate-output --checklist 'Selecione os Programas:' 22 78 12 \
			1A 'Kit X Server    (xfree86)'                                           on    \
			1B 'Kit Gráfico 1   (kdebase, kdm)'                                      on    \
			1C 'Kit Gráfico 2   (blackbox, xdm)'                                     on    \
			1D 'Kit KDE Desktop (kopete, kmail, kscd, kuickshow, kdegames)'          on    \
			1E 'Kit KDE CD/DVD  (k3b, libcdparanoia0)'                               on    \
			1F 'Kit CD/DVD      (cdrecord, cdrdao, mkisofs, cdda2wav)'               on    \
			1G 'Kit Internet    (mozilla, xchat, xpdf, ftp)'                         on    \
			1H 'Kit MultiMidia  (xmms, xine)'                                        on    \
			1I 'Kit Impressão   (cupsys, cupsys-bsd, cupsys-driver-gimpprint)'       on    \
			1J 'Kit Compilação  (make, gcc, libncurses5-dev, kernel-headers)'        on    \
			1L 'Kit Utilitários (unzip, unrar)'                               on    \
			1M 'Kit Wine        (wine, wine-utils, winesetuptk)'                     on 2> /tmp/.geek.apt

	if [ "$?" = '0' ] ; then

		dialog --no-shadow --backtitle "$TITLE" \
			--begin   2  1 --infobox 'Anterior..: Seleção de Pacotes Debian Woody Backports. \nAtual.....: Instalação de Pacotes Debian Woody Backports.      [05 de 10]\nPróximo...: Seleção de Programas Adicionais.   \n' 5 78 \
			--and-widget \
			--begin   12  15 --shadow --infobox '\n           Instalando Backports.   \n' 5 50

		grava_log "Instalando Backports."
		unset sAptGet

		cat /tmp/.geek.apt | tr -d '	' | while read sApt ; do
			touch /tmp/.geek.apt.$sApt
		done

		grava_log "Configurando APT."
		echo "deb file:$BASE_PATH ./" > /etc/apt/sources.list
		grava_log "Atualizando APT."
		apt-get update > /dev/null 2>&1
		grava_log "Instalando Backports."

		if [ "$VERBOSE" != 'on' ] ; then
			APT='-qqy'
			OUT='> /dev/null 2>&1'
		else
			APT='-y'
		fi

		eval "apt-get $APT install xloadimage bzip2 joe locales eject sudo $OUT"

		if [ -e /tmp/.geek.apt.1A ] ; then
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Pacotes Debian Woody Backports. \nAtual.....: Instalação de Pacotes Debian Woody Backports.      [05 de 10]\nPróximo...: Seleção de Programas Adicionais.   \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n   Instalando X-Window-System / Xfree 4.3.0. \n' 5 50
			grava_log "Instalando X-Window-System / Xfree 4.3.0."
			eval "apt-get $APT install x-window-system $OUT"
			debug
		fi

		if [ -e /tmp/.geek.apt.1B ] ; then
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Pacotes Debian Woody Backports. \nAtual.....: Instalação de Pacotes Debian Woody Backports.      [05 de 10]\nPróximo...: Seleção de Programas Adicionais.   \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n           Instalando KDE Basico.           \n' 5 50
			grava_log "Instalando KDE 3.1.4."
			eval "apt-get $APT install kdebase kdm $OUT"
			debug
		fi

		if [ -e /tmp/.geek.apt.1C ] ; then
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Pacotes Debian Woody Backports. \nAtual.....: Instalação de Pacotes Debian Woody Backports.      [05 de 10]\nPróximo...: Seleção de Programas Adicionais.   \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n           Instalando Blackbox.            \n' 5 50
			grava_log "Instalando Blackbox."
			eval "apt-get $APT install blackbox $OUT"
			debug
		fi

		if [ -e /tmp/.geek.apt.1D ] ; then 
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Pacotes Debian Woody Backports. \nAtual.....: Instalação de Pacotes Debian Woody Backports.      [05 de 10]\nPróximo...: Seleção de Programas Adicionais.   \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n          Instalando KDE Desktop.          \n' 5 50
			grava_log "Instalando KDE Desktop."
			eval "apt-get $APT install kopete kmail kscd kuickshow kde-i18n-ptbr superkaramba kdegames kppp kghostview $OUT"
			debug
		fi

		if [ -e /tmp/.geek.apt.1E ] ; then
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Pacotes Debian Woody Backports. \nAtual.....: Instalação de Pacotes Debian Woody Backports.      [05 de 10]\nPróximo...: Seleção de Programas Adicionais.   \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n             Instalando K3B.               \n' 5 50
			grava_log "Instalando K3b."
			eval "apt-get $APT install k3b cdparanoia $OUT"
			debug
		fi

		if [ -e /tmp/.geek.apt.1F ] ; then
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Pacotes Debian Woody Backports. \nAtual.....: Instalação de Pacotes Debian Woody Backports.      [05 de 10]\nPróximo...: Seleção de Programas Adicionais.   \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n        Instalando Gravador CD/DVD.        \n' 5 50
			grava_log "Instalando CD/DVD."
			eval "apt-get $APT install cdrecord cdrdao mkisofs cdda2wav $OUT"
			debug
		fi

		if [ -e /tmp/.geek.apt.1G ] ; then
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Pacotes Debian Woody Backports. \nAtual.....: Instalação de Pacotes Debian Woody Backports.      [05 de 10]\nPróximo...: Seleção de Programas Adicionais.   \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n       Instalando Navegador / Chat.        \n' 5 50
			grava_log "Instalando Internet."
			eval "apt-get $APT install mozilla xchat xpdf ftp $OUT"
			debug
		fi

		if [ -e /tmp/.geek.apt.1H ] ; then
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Pacotes Debian Woody Backports. \nAtual.....: Instalação de Pacotes Debian Woody Backports.      [05 de 10]\nPróximo...: Seleção de Programas Adicionais.   \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n          Instalando Multimidia.           \n' 5 50
			grava_log "Instalando Multimidia."
			eval "apt-get $APT install xmms xine-ui libdvdcss2 $OUT"
			debug
		fi

		if [ -e /tmp/.geek.apt.1I ] ; then
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Pacotes Debian Woody Backports. \nAtual.....: Instalação de Pacotes Debian Woody Backports.      [05 de 10]\nPróximo...: Seleção de Programas Adicionais.   \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n           Instalando Impressão.           \n' 5 50
			grava_log "Instalando Impressão."
			eval "apt-get $APT install cupsys cupsys-bsd cupsys-driver-gimpprint escputil $OUT"
			debug
		fi

		if [ -e /tmp/.geek.apt.1J ] ; then
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Pacotes Debian Woody Backports. \nAtual.....: Instalação de Pacotes Debian Woody Backports.      [05 de 10]\nPróximo...: Seleção de Programas Adicionais.   \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n          Instalando Compilador.           \n' 5 50
			grava_log "Instalando Compilador."
			KERNEL=$(uname -r)
			if [ "$KERNEL" = '2.4.18-bf2.4' ] ; then
				eval "apt-get $APT install make gcc libncurses5-dev binutils kernel-headers-2.4.18-bf2.4 $OUT"
				dpkg --configure -a > /dev/null 2>&1
				cd /usr/src
				rm linux > /dev/null 2>&1
				ln -s kernel-headers-2.4.18-bf2.4 linux
				cd /lib/modules/2.4.18-bf2.4
				rm build > /dev/null 2>&1
				ln -s /usr/src/kernel-headers-2.4.18-bf2.4 build
			else
				eval "apt-get $APT install make gcc libncurses5-dev binutils $OUT"
			fi
			unset KERNEL
			debug
		fi

		if [ -e /tmp/.geek.apt.1L ] ; then
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Pacotes Debian Woody Backports. \nAtual.....: Instalação de Pacotes Debian Woody Backports.      [05 de 10]\nPróximo...: Seleção de Programas Adicionais.   \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n         Instalando Utilitarios.           \n' 5 50
			grava_log "Instalando Utilitarios."
			eval "apt-get $APT install unzip bzip2 unrar libstdc++2.9-glibc2.1 $OUT"
			debug
		fi

		if [ -e /tmp/.geek.apt.1M ] ; then
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Pacotes Debian Woody Backports. \nAtual.....: Instalação de Pacotes Debian Woody Backports.      [05 de 10]\nPróximo...: Seleção de Programas Adicionais.   \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n             Instalando Wine.              \n' 5 50
			grava_log "Backport Wine selecionado."
			eval "apt-get $APT install wine wine-utils winesetuptk $OUT"
			debug
		fi

		grava_log "Instalação dos Backports Concluida."
	else
		grava_log "Pulando Instalação de Backports."
		debug
	fi

### Seleção de Programas Adicionais ###

	dialog --no-shadow --backtitle "$TITLE" \
		--begin   2  1 --infobox 'Anterior..: Instalação de Pacotes Debian Woody Backports. \nAtual.....: Seleção de Programas Adicionais.                   [06 de 10]\nPróximo...: Instalação de Programas Adicionais.  \n' 5 78 \
		--and-widget \
		--begin   7 1 --title "Programas Adicionais" --ok-label "Instalar" --cancel-label "Pular Etapa" --separate-output --checklist 'Selecione os Programas Adicionais:' 22 78 12 \
			2A 'Nvidia Drivers (NVIDIA 4496-pkg2, 5328-pkg1, 5336-pkg1, 6106-pkg1)' off   \
			2B 'Radeon Drivers (fglrx_4.2.0-3.7.6_i386.deb)'                        off   \
			2C 'Flash 7 r25    (flash_plugin_v7_r25.tar.gz)'                        on    \
			2D 'Java 2 RunTime (j2re-1_4_2_05-linux-i586.bin)'                      on    \
			2E 'Kernel Source  (linux-2.4.27.tar.gz)'                              off   \
			2F 'Netscape7 BR   (netscape702pt-i686-pc-linux-gnu-sea.tar.gz)'        off   \
			2G 'OpenOffice 1.1 (OOo_1.1rc4_LinuxIntel_install.pt-br.tar.gz)'        on    \
			2H 'RealPlayer8    (rp8_linux20_libc6_i386_cs2.bin)'                    off   \
			2I 'Xine Codecs    (win32-codecs-full.tar.gz)'                          on    \
			2J 'Xine Skins     (themes-xine.tar.gz)'                                on    \
			2L 'Xmms Skins     (themes-xmms.tar.gz)'                                on    \
			2M 'Wallpapers     (themes-wallpapers.tar.gz)'                          on 2> /tmp/.geek.adic

	if [ "$?" = '0' ] ; then

		cat /tmp/.geek.adic | tr -d '	' | while read sPrograma ; do
			touch /tmp/.geek.adic.$sPrograma
		done

		if [ -e /tmp/.geek.adic.2A ] ; then
			grava_log "Instalando NVIDIA Drivers."
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Programas Adicionais.    \nAtual.....: Instalação de Programas Adicionais.                [07 de 10]\nPróximo...: Configurando Geek Desktop.  \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n        Instalando Drivers da NVIDIA...   \n' 5 50
			/etc/init.d/xdm stop > /dev/null 2>&1
			/etc/init.d/kdm stop > /dev/null 2>&1
			cp -a $BASE_PATH/geek-base/drivers/NVIDIA* /root/geek
	
			true
			while [ "$?" = '0' ] ; do
				unset NvidiaErro
				if [ "$VERBOSE" = 'on' ] ; then
					sh /root/geek/NVIDIA-Linux-x86-1.0-6106-pkg1.run -q -n --no-network
				else
					sh /root/geek/NVIDIA-Linux-x86-1.0-6106-pkg1.run -s -n --no-network > /dev/null 2>&1
				fi
				if [ "$?" = '1' ] ; then
					NvidiaErro=1
					dialog --no-shadow --backtitle "$TITLE" \
						--begin   2  1 --infobox 'Anterior..: Seleção de Programas Adicionais.    \nAtual.....: Instalação de Programas Adicionais.                [07 de 10]\nPróximo...: Configurando Geek Desktop.  \n' 5 78 \
						--and-widget \
						--begin   11  15 --shadow --yesno '\n  Ocorreu um erro na instalação do Driver, \n          Deseja tentar novamente?  \n' 8 50
				else
					false
				fi
			done

			if [ -z "$NvidiaErro" ] ; then
				if ! (cat /etc/modules | grep nvidia > /dev/null 2> /dev/null) ; then
					echo nvidia >> /etc/modules
				fi
				sed -e 's/VIDEO1/nvidia/g' "$BASE_PATH"/geek-inst/XF86Config-4 > /tmp/.geek.XF86Config-4.ok
			fi
			debug
		fi
	
		if [ -e /tmp/.geek.adic.2B ] ; then
			grava_log "Instalando RADEON Drivers."
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Programas Adicionais.    \nAtual.....: Instalação de Programas Adicionais.                [07 de 10]\nPróximo...: Configurando Geek Desktop.  \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n         Copiando Drivers da RADEON...   \n' 5 50
			cp -a $BASE_PATH/geek-base/drivers/fglrx_4.2.0-3.7.6_i386.deb /root/geek
			debug
		fi
	
		if [ -e /tmp/.geek.adic.2E ] ; then
			grava_log "Instalando Kernel Source."
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Programas Adicionais.    \nAtual.....: Instalação de Programas Adicionais.                [07 de 10]\nPróximo...: Configurando Geek Desktop.  \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n            Instalando Linux 2.4.27.   \n' 5 50

			cd /usr/src
			cp "$BASE_PATH"/geek-base/linux-2.4.27.tar.gz .
			tar xzf linux-2.4.27.tar.gz
			rm -r linux kernel-source-2.4.27 > /dev/null 2>&1
			ln -s linux-2.4.27 linux
			ln -s linux-2.4.27 kernel-source-2.4.27
			cd linux
			cp "$BASE_PATH"/geek-inst/config-2.4.27 .config
			debug
		fi
	
		if [ -e /tmp/.geek.adic.2F ] ; then
			grava_log "Instalando Netscape."
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Programas Adicionais.    \nAtual.....: Instalação de Programas Adicionais.                [07 de 10]\nPróximo...: Configurando Geek Desktop.  \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n             Copiando Netscape7...   \n' 5 50
			cp -a $BASE_PATH/geek-base/netscape702pt-i686-pc-linux-gnu-sea.tar.gz /root/geek
			cd /root/geek
			tar xzf netscape702pt-i686-pc-linux-gnu-sea.tar.gz
			debug
		fi
	
		if [ -e /tmp/.geek.adic.2G ] ; then
			grava_log "Instalando OpenOffice."
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Programas Adicionais.    \nAtual.....: Instalação de Programas Adicionais.                [07 de 10]\nPróximo...: Configurando Geek Desktop.  \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n          Instalando OpenOffice 1.1...  \n' 5 50
			cd /opt
			tar xzf $BASE_PATH/geek-base/OpenOffice.org1.1.0.tar.gz
			chmod 777 /opt/OpenOffice.org1.1.0/user/basic
			debug
		fi
	
		if [ -e /tmp/.geek.adic.2H ] ; then
			grava_log "Instalando RealPlayer."
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Programas Adicionais.    \nAtual.....: Instalação de Programas Adicionais.                [07 de 10]\nPróximo...: Configurando Geek Desktop.  \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n           Copiando RealPlayer 8...   \n' 5 50
			cp -a $BASE_PATH/geek-base/rp8_linux20_libc6_i386_cs2.bin /root/geek
			debug
		fi
	
		if [ -e /tmp/.geek.adic.2C ] ; then
			grava_log "Instalando Flash Plugin."
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Programas Adicionais.    \nAtual.....: Instalação de Programas Adicionais.                [07 de 10]\nPróximo...: Configurando Geek Desktop.  \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n         Instalando Flash Plugin r81...   \n' 5 50
			for i in /opt/netscape /usr/local/netscape /usr/lib/mozilla ; do
				gmkdir "$i"
				gmkdir "$i/plugins"
				cd "$i/plugins"
				tar xzf $BASE_PATH/geek-base/flash_plugin_v7_r25.tar.gz
				chown root.root "$i/plugins/" -R
			done
			debug
		fi
	
		if [ -e /tmp/.geek.adic.2D ] ; then
			grava_log "Instalando Java RunTime."
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Programas Adicionais.    \nAtual.....: Instalação de Programas Adicionais.                [07 de 10]\nPróximo...: Configurando Geek Desktop.  \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n  Instalando Java RunTime 1.4.2_04...            \n           Digite: yes ou no' 6 50
			sleep 4
			cd /opt
			sh $BASE_PATH/geek-base/j2re-1_4_2_05-linux-i586.bin
	
			for i in /opt/netscape /usr/local/netscape /usr/lib/mozilla ; do
				gmkdir $i
				gmkdir $i/plugins
				cd "$i/plugins"
				ln -s /opt/j2re1.4.2_05/plugin/i386/ns610/libjavaplugin_oji.so .
			done
			debug
		fi
	
		if [ -e /tmp/.geek.adic.2I ] ; then
			grava_log "Instalando Xine Codecs."
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Programas Adicionais.    \nAtual.....: Instalação de Programas Adicionais.                [07 de 10]\nPróximo...: Configurando Geek Desktop.  \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n          Instalando Xine Codecs...            \n    Avi, MPG, DivX, XviD, ASF, QuickTime' 6 50
			cd /usr/lib
			tar xzf $BASE_PATH/geek-base/win32-codecs-full.tar.gz
			chown root.root /usr/lib/win32 -R
			debug
		fi


		if [ -e /tmp/.geek.adic.2J ] ; then
			grava_log "Instalando Xine Skins."
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Programas Adicionais.    \nAtual.....: Instalação de Programas Adicionais.                [07 de 10]\nPróximo...: Configurando Geek Desktop.  \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n           Instalando Xine Skins...   \n' 5 50
			gmkdir /usr/share/xine/skins
			cd /usr/share/xine/skins
			tar xzf $BASE_PATH/geek-base/themes-xine.tar.gz
			chown root.root /usr/share/xine/skins -R
			debug
		fi

		if [ -e /tmp/.geek.adic.2L ] ; then
			grava_log "Instalando Xmms Skins."
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Programas Adicionais.    \nAtual.....: Instalação de Programas Adicionais.                [07 de 10]\nPróximo...: Configurando Geek Desktop.  \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n           Instalando Xmms Skins...   \n' 5 50
			gmkdir /usr/share/xmms/Skins
			cd /usr/share/xmms/Skins
			tar xzf $BASE_PATH/geek-base/themes-xmms.tar.gz
			chown root.root /usr/share/xmms/Skins -R
			debug
		fi

		if [ -e /tmp/.geek.adic.2M ] ; then
			grava_log "Instalando Wallpapers."
			dialog --no-shadow --backtitle "$TITLE" \
				--begin   2  1 --infobox 'Anterior..: Seleção de Programas Adicionais.    \nAtual.....: Instalação de Programas Adicionais.                [07 de 10]\nPróximo...: Configurando Geek Desktop.  \n' 5 78 \
				--and-widget \
				--begin   12  15 --shadow --infobox '\n           Instalando Wallpapers...   \n' 5 50
			gmkdir /usr/share/wallpapers
			cd /usr/share/wallpapers
			tar xzf $BASE_PATH/geek-base/themes-wallpapers.tar.gz
			chown root.root /usr/share/wallpapers -R
			debug
		fi

		grava_log "Instalação de Programas Adicionais Concluída."
	else
		grava_log "Pulando Instalação de Programas Adicionais."
		debug
	fi


### Configurando Geek Desktop ###

	grava_log "Configurando Geek Desktop."
	dialog --no-shadow --backtitle "$TITLE" \
		--begin   2  1 --infobox 'Anterior..: Instalação dos Programas Adicionais.              \nAtual.....: Configurando Geek Desktop.                         [08 de 10]\nPróximo...: Testar Interface Gráfica.          \n' 5 78 \
		--and-widget \
		--begin   7  1 --title "Configurando Geek Desktop" --infobox "\n * Configurando Geek Desktop.\n" 22 78

	cp -a "$BASE_PATH"/geek-inst/environment /etc
	cp -a "$BASE_PATH"/geek-inst/locale.gen /etc
	cp -a "$BASE_PATH"/geek-inst/locale.alias /etc
	locale-gen > /dev/null 2>&1
	cp -a "$BASE_PATH"/geek-inst/inetd.conf /etc
	cp -a "$BASE_PATH"/geek-inst/profile /etc
	cp -a "$BASE_PATH"/geek-inst/cron.exim /etc/cron.d/exim
	cp -a "$BASE_PATH"/geek-inst/sudoers /etc
	chmod 440 /etc/sudoers
	cp -a "$BASE_PATH"/geek-inst/backgroundrc /etc/kde3/kdm
	cp -a "$BASE_PATH"/geek-inst/ppp-options /etc/ppp/options
	cp -a "$BASE_PATH"/geek-inst/ppp-pap-secrets /etc/ppp/pap-secrets
	chmod 600 /etc/ppp/pap-secrets
	if [ -e /usr/bin/kppp ] ; then
		chmod 4755 /usr/bin/kppp
	fi
	if [ -e /usr/bin/cdrecord ] ; then
		chmod 4755 /usr/bin/cdrecord
	fi
	if [ -e /usr/bin/cdrecord.mmap ] ; then
		chmod 4755 /usr/bin/cdrecord.mmap
	fi
	if [ -e /usr/bin/cdrdao ] ; then
		chmod 4755 /usr/bin/cdrdao
	fi
	if [ -x /usr/bin/drkonqi ] ; then
		mv /usr/bin/drkonqi /usr/bin/drkonqi.inutil
	fi
	if [ -d /etc/joe ] ; then
		cp -a "$BASE_PATH"/geek-inst/joerc /etc/joe
	fi
	sDev=$(readlink /dev/cdrom)
	if [ -e /dev/$sDev ] ; then
		chown .cdrom /dev/$sDev
	fi
	sed -e s/KLOGD=\"\"/KLOGD=\"-c\ 3\"/ /etc/init.d/klogd > /etc/init.d/klogd.new
	mv /etc/init.d/klogd.new /etc/init.d/klogd
	chmod 755 /etc/init.d/klogd
	echo '/usr/bin/kdm' > /etc/X11/default-display-manager
	update-rc.d -f exim remove > /dev/null 2>&1
	update-rc.d -f xdm remove > /dev/null 2>&1
	cat "$BASE_PATH"/geek-inst/setleds  >> /etc/init.d/bootmisc.sh

	debug

	grava_log "Configurando Sources.list default."
	dialog --no-shadow --backtitle "$TITLE" \
		--begin   2  1 --infobox 'Anterior..: Instalação dos Programas Adicionais.              \nAtual.....: Configurando Geek Desktop.                         [08 de 10]\nPróximo...: Testar Interface Gráfica.          \n' 5 78 \
		--and-widget \
		--begin   7  1 --title "Configurando Geek Desktop" --infobox "\n * Configurando Geek Desktop.\n
 * Configurando /etc/apt/sources.list" 22 78

	cp -a "$BASE_PATH"/geek-inst/sources.list /etc/apt/sources.list
	debug

	grava_log "Configurando Personalização do KDE."
	dialog --no-shadow --backtitle "$TITLE" \
		--begin   2  1 --infobox 'Anterior..: Instalação dos Programas Adicionais.              \nAtual.....: Configurando Geek Desktop.                         [08 de 10]\nPróximo...: Testar Interface Gráfica.          \n' 5 78 \
		--and-widget \
		--begin   7  1 --title "Configurando Geek Desktop" --infobox "\n * Configurando Geek Desktop.\n
 * Configurando /etc/apt/sources.list\n
 * Configurando o KDE." 22 78

	cd /etc/skel
	tar xzf $BASE_PATH/geek-base/kde-conf.tar.gz
	chown root.root /etc/skel -R
	cd /root
	mv /root/.profile /tmp/.geek.profile
	tar xzf $BASE_PATH/geek-base/kde-conf.tar.gz
	mv /tmp/.geek.profile /root/.profile
	cp "$BASE_PATH"/geek-inst/bashrc-root /root/.bashrc
	rm /root/.bash_profile > /dev/null 2>&1
	chown root.root /root -R
	cp "$BASE_PATH"/geek-inst/karamba-start /usr/bin
	chmod 755 /usr/bin/karamba-start
	gmkdir /usr/share/superkaramba
	cd /usr/share/superkaramba
	tar xzf "$BASE_PATH"/geek-base/theme-karamaba-geek.tar.gz
	sed -e "s/USER/root/g" "$BASE_PATH"/geek-inst/xine-config > /root/.xine/config

	for i in /home/* ; do
		if [ "$i" != '/home/lost+found' ] ; then
			User=$(echo $i | cut -f3 -d '/')
			if [ -d "$i" ] ; then
				adduser $User audio   > /dev/null 2>&1
				adduser $User dip     > /dev/null 2>&1
				adduser $User dialout > /dev/null 2>&1
				adduser $User cdrom   > /dev/null 2>&1
				cd "$i"
				tar xzf "$BASE_PATH"/geek-base/kde-conf.tar.gz
				sed -e "s/USER/$User/g" "$BASE_PATH"/geek-inst/xine-config > /home/$User/.xine/config
				chmod 644 /home/$User/.superkaramba/geek.rc
				chown $User.users $i -R
			fi
		fi
	done
	debug

	grava_log "Configurando Debian Boot Screen."
	dialog --no-shadow --backtitle "$TITLE" \
		--begin   2  1 --infobox 'Anterior..: Instalação dos Programas Adicionais.              \nAtual.....: Configurando Geek Desktop.                         [08 de 10]\nPróximo...: Testar Interface Gráfica.          \n' 5 78 \
		--and-widget \
		--begin   7  1 --title "Configurando Geek Desktop" --infobox "\n * Configurando Geek Desktop.\n
 * Configurando /etc/apt/sources.list.\n
 * Configurando o KDE.\n
 * Configurando Debian BootScreen / BootSplash." 22 78

	# Espaco Reservado.


	Loop2='0'
	while [ "$Loop2" = '0' ] ; do

	if ! [ -e /tmp/.geek.XF86Config-4.ok ] ; then
		grava_log "Configurando Driver de Video."
		cp -a "$BASE_PATH"/geek-inst/XF86Config-4 /tmp/.geek.XF86Config-4
		dialog --no-shadow --backtitle "$TITLE" \
			--begin   2  1 --infobox 'Anterior..: Instalação dos Programas Adicionais.              \nAtual.....: Configurando Geek Desktop.                         [08 de 10]\nPróximo...: Testar Interface Gráfica.          \n' 5 78 \
			--and-widget \
			--begin   7  1 --title "Configurando Geek Desktop" --infobox "\n * Configurando Geek Desktop.\n
 * Configurando /etc/apt/sources.list.\n
 * Configurando o KDE.\n
 * Configurando Debian Boot Screen." 8 78 \
			--and-widget \
			--begin   15  1 --no-cancel --title "Configurando o Driver da Placa de Video" --stdout --radiolist 'Selecione:' 14 78 6 \
			7A 'vesa [Genérico]'    on  \
			7B 'apm'                off \
			7C 'ark'                off \
			7D 'ati'                off \
			7E 'chips'              off \
			7F 'cirrus'             off \
			7G 'cyrix'              off \
			7H 'fbdev'              off \
			7I 'glide'              off \
			7J 'glint'              off \
			7K 'i128'               off \
			7L 'i740'               off \
			7M 'i810'               off \
			7N 'imstt'              off \
			7O 'mga'                off \
			7P 'neomagic'           off \
			7Q 'newport'            off \
			7R 'nv'                 off \
			7S 'nvidia'             off \
			7T 'rendition'          off \
			7U 's3'                 off \
			7V 's3virge'            off \
			7W 'savage'             off \
			7X 'siliconmotion'      off \
			7Y 'sis'                off \
			7Z 'tdfx'               off \
			70 'tga'                off \
			71 'trident'            off \
			72 'tseng'              off \
			73 'v4l'                off \
			74 'vga'                off \
			75 'vmware'             off > /tmp/.geek.video.driver

			sDriver=$(cat /tmp/.geek.video.driver)
			case "$sDriver" in
				7A)
					sed -e 's/VIDEO1/vesa/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7B)
					sed -e 's/VIDEO1/apm/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7C)
					sed -e 's/VIDEO1/ark/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7D)
					sed -e 's/VIDEO1/ati/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7E)
					sed -e 's/VIDEO1/chips/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7F)
					sed -e 's/VIDEO1/cirrus/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7G)
					sed -e 's/VIDEO1/cyrix/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7H)
					sed -e 's/VIDEO1/fbdev/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7I)
					sed -e 's/VIDEO1/glide/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7J)
					sed -e 's/VIDEO1/glint/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7K)
					sed -e 's/VIDEO1/i128/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7L)
					sed -e 's/VIDEO1/i740/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7M)
					sed -e 's/VIDEO1/i810/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7N)
					sed -e 's/VIDEO1/imstt/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7O)
					sed -e 's/VIDEO1/mga/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7P)
					sed -e 's/VIDEO1/neomagic/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7Q)
					sed -e 's/VIDEO1/newport/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7R)
					sed -e 's/VIDEO1/nv/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7S)
					sed -e 's/VIDEO1/nvidia/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7T)
					sed -e 's/VIDEO1/rendition/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7U)
					sed -e 's/VIDEO1/s3/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7V)
					sed -e 's/VIDEO1/s3virge/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7W)
					sed -e 's/VIDEO1/savage/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7X)
					sed -e 's/VIDEO1/siliconmotion/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7Y)
					sed -e 's/VIDEO1/sis/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				7Z)
					sed -e 's/VIDEO1/tdfx/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				70)
					sed -e 's/VIDEO1/tga/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				71)
					sed -e 's/VIDEO1/trident/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				72)
					sed -e 's/VIDEO1/tseng/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				73)
					sed -e 's/VIDEO1/v4l/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				74)
					sed -e 's/VIDEO1/vga/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
				75)
					sed -e 's/VIDEO1/vmware/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
				;;
			esac
			mv /tmp/.geek.XF86Config-4.tmp /tmp/.geek.XF86Config-4
			debug
		else
			cp /tmp/.geek.XF86Config-4.ok /tmp/.geek.XF86Config-4
		fi


		grava_log "Configurando Teclado."
		dialog --no-shadow --backtitle "$TITLE" \
			--begin   2  1 --infobox 'Anterior..: Instalação dos Programas Adicionais.              \nAtual.....: Configurando Geek Desktop.                         [08 de 10]\nPróximo...: Testar Interface Gráfica.          \n' 5 78 \
			--and-widget \
			--begin   7  1 --title "Configurando Geek Desktop" --infobox "\n * Configurando Geek Desktop.\n
 * Configurando /etc/apt/sources.list.\n
 * Configurando o KDE.\n
 * Configurando Debian Boot Screen." 8 78 \
			--and-widget \
			--begin   15  1 --no-cancel --title "Configurando Teclado no Console e Modo Grafico" --stdout --radiolist 'Selecione:' 14 78 3 \
                        3A 'Modelo Abnt2	( Com cedilha )'      on  \
                        3B 'Modelo Pc104	( Sem cedilha )'      off \
			3C 'Exibir lista completa.'                 off > /tmp/.geek.video.teclado

			sTeclado=$(cat /tmp/.geek.video.teclado)

			case "$sTeclado" in
				3A)
					sed -e 's/TECLADO1/abnt2/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					sed -e 's/TECLADO2/br/g' /tmp/.geek.XF86Config-4.tmp > /tmp/.geek.XF86Config-4
					install-keymap br-abnt2 > /dev/null 2>&1
				;;
				3B)
					sed -e 's/TECLADO1/pc104/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					sed -e 's/TECLADO2/us_intl/g' /tmp/.geek.XF86Config-4.tmp > /tmp/.geek.XF86Config-4
					install-keymap br-latin1 > /dev/null 2>&1
				;;
				3C)
					sed -e 's/TECLADO1/abnt2/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					sed -e 's/TECLADO2/br/g' /tmp/.geek.XF86Config-4.tmp > /tmp/.geek.XF86Config-4
					dpkg-reconfigure console-data
				;;
			esac
			debug


		grava_log "Configurando Mouse."
		dialog --no-shadow --backtitle "$TITLE" \
			--begin   2  1 --infobox 'Anterior..: Instalação dos Programas Adicionais.              \nAtual.....: Configurando Geek Desktop.                         [08 de 10]\nPróximo...: Testar Interface Gráfica.          \n' 5 78 \
			--and-widget \
			--begin   7  1 --title "Configurando Geek Desktop" --infobox "\n * Configurando Geek Desktop.\n
 * Configurando /etc/apt/sources.list.\n
 * Configurando o KDE.\n
 * Configurando Debian Boot Screen." 8 78 \
			--and-widget \
			--begin   15  1 --no-cancel --title "Configurando Mouse no Modo Grafico" --stdout --radiolist 'Selecione:' 14 78 6 \
                        4A 'Modelo Serial0  ( ms      /dev/ttyS0               )'  off \
                        4B 'Modelo Serial1  ( ms      /dev/ttyS1               )'  off \
                        4C 'Modelo MiniDim  ( ps/2    /dev/psaux               )'  on  \
                        4D 'Modelo MiniDim  ( imps/2  /dev/psaux + Scroll      )'  off \
                        4E 'Modelo USB      ( ps/2    /dev/input/mice          )'  off \
                        4F 'Modelo USB      ( imps/2  /dev/input/mice + Scroll )'  off > /tmp/.geek.video.mouse

			sMouse=$(cat /tmp/.geek.video.mouse)

			case "$sMouse" in
				4A)
					sed -e 's/MOUSE1/\/dev\/ttyS0/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					sed -e 's/MOUSE2/Microsoft/g' /tmp/.geek.XF86Config-4.tmp > /tmp/.geek.XF86Config-4
				;;
				4B)
					sed -e 's/MOUSE1/\/dev\/ttyS1/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					sed -e 's/MOUSE2/Microsoft/g' /tmp/.geek.XF86Config-4.tmp > /tmp/.geek.XF86Config-4
				;;
				4C)
					sed -e 's/MOUSE1/\/dev\/psaux/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					sed -e 's/MOUSE2/PS\/2/g' /tmp/.geek.XF86Config-4.tmp > /tmp/.geek.XF86Config-4
				;;
				4D)
					sed -e 's/MOUSE1/\/dev\/psaux/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					sed -e 's/MOUSE2/ImPS\/2/g' /tmp/.geek.XF86Config-4.tmp > /tmp/.geek.XF86Config-4
				;;
				4E)
					sed -e 's/MOUSE1/\/dev\/input\/mice/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					sed -e 's/MOUSE2/PS\/2/g' /tmp/.geek.XF86Config-4.tmp > /tmp/.geek.XF86Config-4
				;;
				4F)
					sed -e 's/MOUSE1/\/dev\/input\/mice/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					sed -e 's/MOUSE2/ImPS\/2/g' /tmp/.geek.XF86Config-4.tmp > /tmp/.geek.XF86Config-4
				;;
			esac
			debug

		grava_log "Configurando Monitor."
		dialog --no-shadow --backtitle "$TITLE" \
			--begin   2  1 --infobox 'Anterior..: Instalação dos Programas Adicionais.              \nAtual.....: Configurando Geek Desktop.                         [08 de 10]\nPróximo...: Testar Interface Gráfica.          \n' 5 78 \
			--and-widget \
			--begin   7  1 --title "Configurando Geek Desktop" --infobox "\n * Configurando Geek Desktop.\n
 * Configurando /etc/apt/sources.list.\n
 * Configurando o KDE.\n
 * Configurando Debian Boot Screen." 8 78 \
			--and-widget \
			--begin   15  1 --no-cancel --title "Configurando Resolução do Monitor no Modo Grafico" --stdout --radiolist 'Selecione:' 14 78 6 \
                        5A '   640x480  ( Monitor 14" e 15" )'      off \
                        5B '   800x600  ( Monitor 14" e 15" )'      off \
                        5C '  1024x768  ( Monitor 14" e 15" )'      on  \
                        5D '  1152x864  ( Monitor 17" e 19" )'      off \
			5E ' 1280x1024  ( Monitor 17" e 19" )'      off \
			5F ' 1600x1200  ( Monitor 19" )'            off \
			5G ' 1792x1344  ( Monitor 19" )'            off  > /tmp/.geek.video.resolucao

			sResolucao=$(cat /tmp/.geek.video.resolucao)
			KERNEL=$(uname -r)
			if [ "$KERNEL" = '2.4.27' ] ; then
				sed -e 's/0x301/0x317/g' /etc/lilo.conf > /tmp/.geek.lilo
				mv /tmp/.geek.lilo /etc/lilo.conf
				lilo > /dev/null 2>&1
			fi

			case "$sResolucao" in
				5A)
					sed -e 's/TELA1/"640x480"/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					sed -e 's/MONITOR1/30-55/g' /tmp/.geek.XF86Config-4.tmp > /tmp/.geek.XF86Config-4.tmp2
					sed -e 's/MONITOR2/60-120/g' /tmp/.geek.XF86Config-4.tmp2 > /tmp/.geek.XF86Config-4
					karamba 640x480
				;;
				5B)
					sed -e 's/TELA1/"800x600" "640x480"/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					sed -e 's/MONITOR1/30-55/g' /tmp/.geek.XF86Config-4.tmp > /tmp/.geek.XF86Config-4.tmp2
					sed -e 's/MONITOR2/60-120/g' /tmp/.geek.XF86Config-4.tmp2 > /tmp/.geek.XF86Config-4
					karamba 800x600
					if [ "$KERNEL" != '2.4.27' ] ; then
						sed -e 's/0x301/0x303/g' /etc/lilo.conf > /tmp/.geek.lilo
						mv /tmp/.geek.lilo /etc/lilo.conf
						lilo > /dev/null 2>&1
					fi
				;;
				5C)
					sed -e 's/TELA1/"1024x768" "800x600" "640x480"/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					sed -e 's/MONITOR1/30-55/g' /tmp/.geek.XF86Config-4.tmp > /tmp/.geek.XF86Config-4.tmp2
					sed -e 's/MONITOR2/60-120/g' /tmp/.geek.XF86Config-4.tmp2 > /tmp/.geek.XF86Config-4
					karamba 1024x768
					if [ "$KERNEL" != '2.4.27' ] ; then
						sed -e 's/0x301/0x305/g' /etc/lilo.conf > /tmp/.geek.lilo
						mv /tmp/.geek.lilo /etc/lilo.conf
						lilo > /dev/null 2>&1
					fi
				;;
				5D)
					sed -e 's/TELA1/"1152x864" "1024x768" "800x600" "640x480"/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					sed -e 's/MONITOR1/30-70/g' /tmp/.geek.XF86Config-4.tmp > /tmp/.geek.XF86Config-4.tmp2
					sed -e 's/MONITOR2/50-160/g' /tmp/.geek.XF86Config-4.tmp2 > /tmp/.geek.XF86Config-4
					if [ "$KERNEL" != '2.4.27' ] ; then
						sed -e 's/0x301/0x305/g' /etc/lilo.conf > /tmp/.geek.lilo
						mv /tmp/.geek.lilo /etc/lilo.conf
						lilo > /dev/null 2>&1
					fi
				;;
				5E)
					sed -e 's/TELA1/"1280x1024" "1152x864" "1024x768" "800x600" "640x480"/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					sed -e 's/MONITOR1/30-70/g' /tmp/.geek.XF86Config-4.tmp > /tmp/.geek.XF86Config-4.tmp2
					sed -e 's/MONITOR2/50-160/g' /tmp/.geek.XF86Config-4.tmp2 > /tmp/.geek.XF86Config-4
					if [ "$KERNEL" != '2.4.27' ] ; then
						sed -e 's/0x301/0x305/g' /etc/lilo.conf > /tmp/.geek.lilo
						mv /tmp/.geek.lilo /etc/lilo.conf
						lilo > /dev/null 2>&1
					fi
				;;
				5F)
					sed -e 's/TELA1/"1600x1200" "1280x1024" "1152x864" "1024x768" "800x600" "640x480"/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					sed -e 's/MONITOR1/30-70/g' /tmp/.geek.XF86Config-4.tmp > /tmp/.geek.XF86Config-4.tmp2
					sed -e 's/MONITOR2/50-160/g' /tmp/.geek.XF86Config-4.tmp2 > /tmp/.geek.XF86Config-4
					if [ "$KERNEL" != '2.4.27' ] ; then
						sed -e 's/0x301/0x305/g' /etc/lilo.conf > /tmp/.geek.lilo
						mv /tmp/.geek.lilo /etc/lilo.conf
						lilo > /dev/null 2>&1
					fi
				;;
				5G)
					sed -e 's/TELA1/"1792x1344" "1600x1200" "1280x1024" "1152x864" "1024x768" "800x600" "640x480"/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					sed -e 's/MONITOR1/30-70/g' /tmp/.geek.XF86Config-4.tmp > /tmp/.geek.XF86Config-4.tmp2
					sed -e 's/MONITOR2/50-160/g' /tmp/.geek.XF86Config-4.tmp2 > /tmp/.geek.XF86Config-4
					if [ "$KERNEL" != '2.4.27' ] ; then
						sed -e 's/0x301/0x305/g' /etc/lilo.conf > /tmp/.geek.lilo
						mv /tmp/.geek.lilo /etc/lilo.conf
						lilo > /dev/null 2>&1
					fi
				;;
			esac
			debug


		grava_log "Configurando Número de Cores."
		dialog --no-shadow --backtitle "$TITLE" \
			--begin   2  1 --infobox 'Anterior..: Instalação dos Programas Adicionais.              \nAtual.....: Configurando Geek Desktop.                         [08 de 10]\nPróximo...: Testar Interface Gráfica.          \n' 5 78 \
			--and-widget \
			--begin   7  1 --title "Configurando Geek Desktop" --infobox "\n * Configurando Geek Desktop.\n
 * Configurando /etc/apt/sources.list.\n
 * Configurando o KDE.\n
 * Configurando Debian Boot Screen." 8 78 \
			--and-widget \
			--begin   15  1 --no-cancel --title "Configurando Número de Cores do Modo Grafico" --stdout --radiolist 'Selecione:' 14 78 3 \
                        6A '256 cores'          off \
                        6B '16 Bits de cores'   on  \
			6C '32 Bits de cores'   off > /tmp/.geek.video.cores

			sCores=$(cat /tmp/.geek.video.cores)

			case "$sCores" in
				6A)
					sed -e 's/BITS1/8/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					mv /tmp/.geek.XF86Config-4.tmp /tmp/.geek.XF86Config-4
				;;
				6B)
					sed -e 's/BITS1/16/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					mv /tmp/.geek.XF86Config-4.tmp /tmp/.geek.XF86Config-4
				;;
				6C)
					sed -e 's/BITS1/24/g' /tmp/.geek.XF86Config-4 > /tmp/.geek.XF86Config-4.tmp
					mv /tmp/.geek.XF86Config-4.tmp /tmp/.geek.XF86Config-4
				;;
			esac
			debug


		grava_log "Testando Configurações de Video."
		dialog --no-shadow --backtitle "$TITLE" \
			--begin   2  1 --infobox 'Anterior..: Configurando Geek Desktop.    \nAtual.....: Testar Interface Gráfica.                          [09 de 10]\nPróximo...: Finalizando.   \n' 5 78 \
			--and-widget \
			--begin   12  15 --shadow --msgbox '\n       Testando Configurações de Video...   \n  Tecle Enter e Aguarde a proxima pergunta...' 8 50

		cp /tmp/.geek.XF86Config-4 /etc/X11/XF86Config-4
		gmkdir /usr/share/wallpapers
		cd /usr/share/wallpapers
		tar xzf $BASE_PATH/geek-base/themes-wallpapers.tar.gz ./Geek_01.jpg
		tar xzf $BASE_PATH/geek-base/themes-wallpapers.tar.gz ./Geek_02.jpg
		tar xzf $BASE_PATH/geek-base/themes-wallpapers.tar.gz ./Geek_03.jpg
		sleep 1
		X > /tmp/.geek.Xout1 2> /tmp/.geek.Xout2 &
		sleep 3
		xloadimage -display 0:0 -onroot -fullscreen /usr/share/wallpapers/Geek_02.jpg > /dev/null 2>&1
		sleep 15
		pidX=$(ps -ef | grep -E ' X$' | awk -F " " '{print $2}')
		kill $pidX > /dev/null 2>&1

		debug

		dialog --no-shadow --backtitle "$TITLE" \
			--begin   2  1 --infobox 'Anterior..: Configurando Geek Desktop.    \nAtual.....: Testar Interface Gráfica.                          [09 de 10]\nPróximo...: Finalizando.   \n' 5 78 \
			--and-widget \
			--shadow --yesno '\n   Deseja usar esta configuração de Video?' 7 50
		if [ "$?" = '0' ] ; then
			grava_log "Configurações de Video Corretas."
			cp /etc/X11/XF86Config-4 /etc/X11/XF86Config-4.custom
			md5sum /etc/X11/XF86Config-4 > /var/lib/xfree86/XF86Config-4.md5sum
			Loop2='1'
		else
			grava_log "Configurações de Video com Erro. Voltando."
			rm /tmp/.geek.XF86Config-4.ok > /dev/null 2>&1
		fi
	done

	grava_log "Finalizando"
	dialog --no-shadow --backtitle "$TITLE" \
		--begin   2  1 --infobox 'Anterior..: Testar Interface Gráfica.    \nAtual.....: Finalizando.                                       [10 de 10]\nPróximo...: ---  \n' 5 78 \
		--and-widget \
		--begin  11  14 --shadow --msgbox "\n        $VERSION Instalado.  \n " 7 50
	/etc/init.d/kdm restart > /dev/null 2>&1
	clear
	switch_debconf --to-medium
	exit
