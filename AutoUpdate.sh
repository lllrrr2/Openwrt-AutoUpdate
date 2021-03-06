#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoUpdate for Openwrt

Version=V5.7

Shell_Helper() {
cat <<EOF

使用方法:	$0 [<更新参数><更新附加参数>]
		$0 [<设置参数>...] [-c] [-boot] <额外参数>
		$0 [<其他>...] [-l] [-d] [-help]

更新参数:
	-n		更新固件 [不保留配置]
	-f		强制更新固件,即跳过版本号验证,自动下载以及安装必要软件包 [保留配置]
	-u		适用于定时更新 LUCI 的参数 [保留配置]
	
更新附加参数:
	-p		优先使用 [FastGit] 镜像加速

设置参数:
	-c		[额外参数:<Github 地址>] 更换 Github 检查更新以及固件下载地址
	-b | -boot	[额外参数:<引导方式 UEFI/Legacy>] 指定 x86 设备下载使用 UEFI/Legacy 引导的固件 [危险]

其他:
	-l | -list	列出设备信息
	-d | -del	清除固件下载缓存
	-h | -help	打印帮助信息
	
EOF
exit 0
}

List_Info() {
cat <<EOF

/overlay 可用:		${Overlay_Available}
/tmp 可用:		${TMP_Available}M
固件下载位置:		/tmp/Downloads
当前设备:		${CURRENT_Device}
默认设备:		${DEFAULT_Device}
当前固件版本:		${CURRENT_Version}
固件名称:		AutoBuild-${CURRENT_Device}-${CURRENT_Version}${Firmware_SFX}
Github 地址:		${Github}
解析 API 地址:		${Github_Tags}
固件下载地址:		${Github_Download}
作者/仓库:		${Author}"
固件格式:		${Firmware_SFX}
EOF
	[[ ${DEFAULT_Device} == "x86_64" ]] && {
		echo "EFI 引导:		${EFI_Mode}"
		echo "固件压缩:		${Compressed_Firmware}"
	}
	exit 0
}

Install_Pkg() {
	PKG_NAME=$1
	if [[ ! "$(cat /tmp/Package_list)" =~ "${PKG_NAME}" ]];then
		[[ "${Force_Update}" == "1" ]] || [[ "${AutoUpdate_Mode}" == "1" ]] && {
			Choose=Y
		} || {
			TIME && read -p "未安装[${PKG_NAME}],是否执行安装?[Y/n]:" Choose
		}
		if [[ "${Choose}" == Y ]] || [[ "${Choose}" == y ]];then
			TIME && echo -e "开始安装[${PKG_NAME}],请耐心等待...\n"
			opkg update > /dev/null 2>&1
			opkg install ${PKG_NAME}
			[[ ! $? -ne 0 ]] && {
				TIME && echo "[${PKG_NAME}] 安装成功!"
			} || {
				TIME && echo "[${PKG_NAME}] 安装失败,请尝试手动安装!"
				exit 1
			}
		else
			TIME && echo "用户已取消安装,即将退出更新脚本..."
			sleep 2
			exit 0
		fi
	fi
}

TIME() {
	echo -ne "\n[$(date "+%H:%M:%S")] "
}

[ ! -f /etc/openwrt_info ] && {
	echo -e "\n未检测到 /etc/openwrt/info,无法运行更新程序!"
	exit 1
}
Input_Option=$1
Input_Other=$2
opkg list | awk '{print $1}' > /tmp/Package_list
CURRENT_Version="$(awk 'NR==1' /etc/openwrt_info)"
Github="$(awk 'NR==2' /etc/openwrt_info)"
Github_Download="${Github}/releases/download/AutoUpdate"
Author="${Github##*com/}"
Github_Tags="https://api.github.com/repos/${Author}/releases/latest"
DEFAULT_Device="$(awk 'NR==3' /etc/openwrt_info)"
Firmware_Type="$(awk 'NR==4' /etc/openwrt_info)"
_PROXY_URL="https://download.fastgit.org"
TMP_Available="$(df -m | grep "/tmp" | awk '{print $4}' | awk 'NR==1' | awk -F. '{print $1}')"
Overlay_Available="$(df -h | grep ":/overlay" | awk '{print $4}' | awk 'NR==1')"
Retry_Times=4
case ${DEFAULT_Device} in
x86_64)
	[[ -z "${Firmware_Type}" ]] && Firmware_Type=img
	[[ "${Firmware_Type}" == img.gz ]] && {
		Compressed_Firmware=1
	} || Compressed_Firmware=0
	[ -f /etc/openwrt_boot ] && {
		BOOT_Type="-$(cat /etc/openwrt_boot)"
	} || {
		[ -d /sys/firmware/efi ] && {
			BOOT_Type="-UEFI"
		} || BOOT_Type="-Legacy"
	}
	case ${BOOT_Type} in
	-Legacy)
		EFI_Mode=0
	;;
	-UEFI)
		EFI_Mode=1
	;;
	esac
	Firmware_SFX="${BOOT_Type}.${Firmware_Type}"
	Detail_SFX="${BOOT_Type}.detail"
	CURRENT_Device=x86_64
	Space_Req=480
;;
*)
	CURRENT_Device="$(jsonfilter -e '@.model.id' < /etc/board.json | tr ',' '_')"
	Firmware_SFX=".${Firmware_Type}"
	[[ -z ${Firmware_SFX} ]] && Firmware_SFX=".bin"
	Detail_SFX=.detail
	Space_Req=0
esac
cd /etc
clear && echo "Openwrt-AutoUpdate Script ${Version}"
if [[ -z "${Input_Option}" ]];then
	Upgrade_Options="-q"
	TIME && echo "执行: 保留配置更新固件"
else
	case ${Input_Option} in
	-n | -f | -u | -np | -pn | -fp | -pf | -up | -pu | -p)
		[[ "${Input_Option}" =~ p ]] && {
			PROXY_URL="${_PROXY_URL}"
			PROXY_ECHO="[FastGit] "
		} || PROXY_ECHO=""
		case ${Input_Option} in
		-n | -np | -pn)
			TIME && echo "${PROXY_ECHO}执行: 更新固件(不保留配置)"
			Upgrade_Options="-n"
		;;
		-f | -pf | -fp)
			Force_Update=1
			Upgrade_Options="-q"
			TIME && echo "${PROXY_ECHO}执行: 强制更新固件(保留配置)"
		;;
		-u | -pu | -up)
			AutoUpdate_Mode=1
			Upgrade_Options="-q"
		;;
		-p | -pq | -qp)
			Upgrade_Options="-q"
			TIME && echo "${PROXY_ECHO}执行: 保留配置更新固件"
		;;
		esac
	;;
	-c)
		if [[ -n "${Input_Other}" ]];then
			sed -i "s?${Github}?${Input_Other}?g" /etc/openwrt_info
			echo -e "\nGithub 地址已更换为: ${Input_Other}"
			unset Input_Other
			exit 0
		else
			Shell_Helper
		fi
	;;
	-l | -list)
		List_Info
	;;
	-d | -del)
		rm -f /tmp/Downloads/* /tmp/Github_Tags
		TIME && echo "固件下载缓存清理完成!"
		exit 0
	;;
	-h | -help)
		Shell_Helper
	;;
	-b | -boot)
		[[ -z "${Input_Other}" ]] && Shell_Helper
		case "${Input_Other}" in
		UEFI | Legacy)
			echo "${Input_Other}" > /etc/openwrt_boot
			sed -i '/openwrt_boot/d' /etc/sysupgrade.conf
			echo -e "\n/etc/openwrt_boot" >> /etc/sysupgrade.conf
			TIME && echo "固件引导方式已指定为: ${Input_Other}!"
			exit 0
		;;
		*)
			echo -e "\n错误的参数: [${Input_Other}],当前支持的选项: [UEFI/Legacy] !"
			exit 1
		;;
		esac
	;;
	*)
		echo -e "\nERROR INPUT: [$*]"
		Shell_Helper
	;;
	esac
fi
if [[ "$(cat /tmp/Package_list)" =~ "curl" ]];then
	Google_Check=$(curl -I -s --connect-timeout 3 google.com -w %{http_code} | tail -n1)
	[[ ! "$Google_Check" == 301 ]] && {
		TIME && echo "Google 连接失败,尝试使用 [FastGit] 镜像加速!"
		PROXY_URL="${_PROXY_URL}"
	}
else
	TIME && echo "无法确定网络环境,默认使用 [FastGit] 镜像加速!"
	PROXY_URL="${_PROXY_URL}"
fi
[[ "${TMP_Available}" -lt "${Space_Req}" ]] && {
	TIME && echo "/tmp 空间不足: [${Space_Req}M],无法执行更新!"
	exit 1
}
Install_Pkg wget
if [[ -z "${CURRENT_Version}" ]];then
	TIME && echo "警告: 当前固件版本获取失败!"
	CURRENT_Version="Unknown"
fi
if [[ -z "${CURRENT_Device}" ]];then
	[[ -n "$DEFAULT_Device" ]] && {
		TIME && echo "警告: 当前设备名称获取失败,使用预设名称: [$DEFAULT_Device]"
		CURRENT_Device="${DEFAULT_Device}"
	} || {
		TIME && echo "未检测到设备名称!"
		exit 1
	}
fi
TIME && echo "正在检查版本更新..."
wget -q ${Github_Tags} -O - > /tmp/Github_Tags
[[ ! $? == 0 ]] && {
	TIME && echo "检查更新失败,请稍后重试!"
	exit 1
}
TIME && echo "正在获取云端固件版本..."
CLOUD_Firmware=$(cat /tmp/Github_Tags | egrep -o "AutoBuild-${CURRENT_Device}-R[0-9].+-[0-9]+${Firmware_SFX}" | awk 'END {print}')
CLOUD_Version=$(echo ${CLOUD_Firmware} | egrep -o "R[0-9].+-[0-9]+")
[[ -z "${CLOUD_Version}" ]] && {
	TIME && echo "云端固件版本获取失败!"
	exit 1
}
Firmware_Name="$(echo ${CLOUD_Firmware} | egrep -o "AutoBuild-${CURRENT_Device}-R[0-9].+-[0-9]+")"
Firmware="${CLOUD_Firmware}"
Firmware_Detail="${Firmware_Name}${Detail_SFX}"
let X=$(grep -n "${Firmware}" /tmp/Github_Tags | tail -1 | cut -d : -f 1)-4
let CLOUD_Firmware_Size=$(sed -n "${X}p" /tmp/Github_Tags | egrep -o "[0-9]+" | awk '{print ($1)/1048576}' | awk -F. '{print $1}')+1
echo -e "\n固件作者: ${Author%/*}"
echo "设备名称: ${CURRENT_Device}"
echo "固件格式: ${Firmware_SFX}"
echo -e "\n当前固件版本: ${CURRENT_Version}"
echo "云端固件版本: ${CLOUD_Version}"
echo "当前可用空间: ${TMP_Available}M"
echo "云端固件大小: ${CLOUD_Firmware_Size}M"
if [[ ! "${Force_Update}" == 1 ]];then
	[[ "${TMP_Available}" -lt "${CLOUD_Firmware_Size}" ]] && {
		TIME && echo "/tmp 空间不足: [${CLOUD_Firmware_Size}M],无法执行更新!"
		exit
	}
	if [[ "${CURRENT_Version}" == "${CLOUD_Version}" ]];then
		[[ "${AutoUpdate_Mode}" == 1 ]] && exit 0
		TIME && read -p "已是最新版本,是否强制更新固件?[Y/n]:" Choose
		[[ "${Choose}" == Y ]] || [[ "${Choose}" == y ]] && {
			TIME && echo "开始强制更新固件..."
		} || {
			TIME && echo "已取消强制更新,即将退出更新程序..."
			sleep 2
			exit 0
		}
	fi
fi
[[ -n "${PROXY_URL}" ]] && Github_Download=${PROXY_URL}/${Author}/releases/download/AutoUpdate
echo -e "\n云端固件名称: ${Firmware}"
echo "固件下载地址: ${Github_Download}"
echo "固件保存位置: /tmp/Downloads"
[ ! -d "/tmp/Downloads" ] && mkdir -p /tmp/Downloads
rm -f /tmp/Downloads/*
TIME && echo "正在下载固件,请耐心等待..."
cd /tmp/Downloads
while [ "${Retry_Times}" -ge 0 ];
do
	if [[ "${Retry_Times}" == 3 ]];then
		[[ -z "${PROXY_URL}" ]] && {
			TIME && echo "正在尝试使用 [FastGit] 镜像加速下载..."
			Github_Download=${_PROXY_URL}/${Author}/releases/download/AutoUpdate
		}
	fi
	if [[ "${Retry_Times}" == 0 ]];then
		TIME && echo "固件下载失败,请检查网络后重试!"
		exit 1
	else
		wget -q --tries 1 --timeout 5 "${Github_Download}/${Firmware}" -O ${Firmware}
		[[ $? == 0 ]] && break
	fi
	Retry_Times=$((${Retry_Times} - 1))
	TIME && echo "下载失败,剩余尝试次数: [${Retry_Times}]"
	sleep 1
done
TIME && echo "固件下载成功!"
TIME && echo "正在获取云端固件MD5,请耐心等待..."
wget -q ${Github_Download}/${Firmware_Detail} -O ${Firmware_Detail}
[[ ! $? == 0 ]] && {
	TIME && echo "MD5 获取失败,请检查网络后重试!"
	exit 1
}
CLOUD_MD5=$(awk -F '[ :]' '/MD5/ {print $2;exit}' ${Firmware_Detail})
CURRENT_MD5=$(md5sum ${Firmware} | cut -d ' ' -f1)
echo -e "\n本地固件MD5:${CURRENT_MD5}"
echo "云端固件MD5:${CLOUD_MD5}"
[[ -z "${CLOUD_MD5}" ]] || [[ -z "${CURRENT_MD5}" ]] && {
	TIME && echo "MD5 获取失败!"
	exit 1
}
[[ "${CLOUD_MD5}" == "${CURRENT_MD5}" ]] && {
	TIME && echo "MD5 对比通过!"
} || {
	TIME && echo "MD5 对比失败,请检查网络后重试!"
	exit 1
}
if [[ "${Compressed_Firmware}" == 1 ]];then
	TIME && echo "检测到固件为 [.gz] 格式,开始解压固件..."
	Install_Pkg gzip
	gzip -dk ${Firmware} > /dev/null 2>&1
	Firmware="${Firmware_Name}${BOOT_Type}.img"
	[ -f "${Firmware}" ] && {
		TIME && echo "固件解压成功,名称: ${Firmware}"
	} || {
		TIME && echo "固件解压失败!"
		exit 1
	}
fi
TIME && echo -e "固件准备就绪,3s 后开始更新..."
sleep 3
TIME && echo "正在更新固件,期间请耐心等待..."
sysupgrade ${Upgrade_Options} ${Firmware}
[[ $? -ne 0 ]] && {
	TIME && echo "固件刷写失败,请尝试手动更新固件!"
	exit 1
}