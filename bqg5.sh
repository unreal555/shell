#!/bin/bash										

SHIJIAN=$(date "+%d%M%S")			#当前时间,注意括号和引号
URL=${1#*//}					#去掉://和之前的协议名,只保留域名和路径
YUMING=${URL%%/*}				#截取出域名
URLPATH=${URL#*/}				#截取路径
WORKPATH=./${SHIJIAN}			#设置工作目录路径 

mkdir ${WORKPATH}				#创建工作目录
touch ${WORKPATH}/list.txt
touch ${WORKPATH}/wrong.txt
mkdir ${WORKPATH}/conv
mkdir ${WORKPATH}/temp
mkdir ${WORKPATH}/txt

THREAD=20					#设置线程数
FIFOTEMP=/tmp/$$.fifo			#设置管道文件路径和文件名,管道文件用于不同进程不同shell之间的通讯,可以多个shell对其进行读取和写入
mkfifo $FIFOTEMP				#创建管道文件
exec 9<>${FIFOTEMP}				#创建文件标志符9并与管道文件相关联


for ((i=1;i<=${THREAD};i++))			#生成THREAD数行的标记,作为生产者消费者标记的对象
  do
      echo "创建线程${i}号"
      echo  "${i}" >&9
  done

echo   时间:$SHIJIAN      小说地址:$URL    域名:$YUMING    相对路径:$URLPATH		工作目录:$WORKPATH	



function geshihua {
  for file in ${1}/*

     do
        sed -i 's/<div id="content">\(.*\)<\/div>/\&nbsp;\&nbsp;\&nbsp;\&nbsp;\1/g'  "${file}"


        echo 删除${file}文件多余行
        sed  -i '/&nbsp;&nbsp;&nbsp;&nbsp;/!d'   "${file}"

        echo 删除${file}文件html标签
        sed -i 's/<[^>]*>//g'  "${file}"


        echo  "删除${file}文件&nbsp"
        sed -i 's/&nbsp;&nbsp;&nbsp;&nbsp;//g'  "${file}"

        echo "去除${file}文件换行符"
        tr "\n" " " <"${file}">"${file}.txt"

        echo "去除${file}文件。。。。。。"
        sed -i 's/ …… …… /\n    /g'  "${file}.txt"

        echo ”${file}文件首行加空格“
        sed -i '1s/.*/    &/g'    "${file}.txt"
        sed -i 's/[root@study txt]#//g'   "${file}.txt"

     done
}

#合并章节
function shuchuquanwen {
    echo -e "目录\n" >>"${WORKPATH}"/"${1}"
    awk '{print $2}' "${WORKPATH}"/list.txt>>"${WORKPATH}"/"${1}"
    echo -e "\n" >>"${WORKPATH}"/"${1}"
    echo -e "\n" >>"${WORKPATH}"/"${1}"

    while read path filename 
       do
         echo  "合并${filename}..."
         echo  -e "${filename}\n" >>"${WORKPATH}"/"${1}"
         cat "${WORKPATH}/txt/${filename}.html.txt" >>"${WORKPATH}"/"${1}"
         echo -e "\n\n\n" >>"${WORKPATH}"/"${1}"
       done<${WORKPATH}/list.txt
    unix2dos "${WORKPATH}"/"${1}"
}


##函数用于下载页面,参数一为地址,参数二为保存路径
function downloadfile {

    echo "开始下载页面$1..."
    sleep 2
    wget "$1" -O "$2"&>/etc/null
    if [ $? -eq 0 ]
        then
           echo   "$2下载成功" 
       else
           echo   "$2下载失败,请检查网络连接和页面地址"|tee -a ${WORKPATH}/wrong.txt
           exit 1
    fi
}

##函数用于转换目录内所有文件,从GBK到UTF8
function gbk2utf8 {
    for file in ${WORKPATH}/temp/*

        do
            echo "$file" 
            iconv -f gbk -t utf-8 "${file}">"${WORKPATH}/conv/${file##*/}"
            
        done
}


##函数用于分析索引文件,提取章节和章节路径,保存在工作目录的list.txt文件.
function getlist {

    sed -n 's/\(<dd><a href="\)\(.*\)\(">\)\(.*\)\(<\/a><\/dd>\)/\2\t\t\t\4/p' $1>${WORKPATH}/list.txt

}

#下载索引页面
downloadfile "$1" "${WORKPATH}/temp/index.html"


#转换字符集,提取章节目录和路径
gbk2utf8
getlist "${WORKPATH}/conv/index.html"

#根据list.txt下载所有章节
while read lujing filename
   do
      read -u 9 i
      {
          echo  "线程${i}号开始下载 ${filename}"
          downloadfile "${YUMING}${lujing}" "${WORKPATH}/temp/${filename}.html"
          echo  "线程${i}号下载结束，释放资源"
          echo  "${i}" >&9
      }&
   done<${WORKPATH}/list.txt
wait

#转换章节字符集
gbk2utf8

cp "${WORKPATH}"/conv/* "${WORKPATH}"/txt/

geshihua "${WORKPATH}/txt/"

rm ${WORKPATH}/txt/*.html

#提取书名
name=$(sed -n 's/<h1>\(.*\)<\/h1>/\1/p' ${WORKPATH}/conv/index.html)

shuchuquanwen ${name}.txt

exec 9>&-
rm -rf "${FIFOTEMP}"
rm -rf "${WORKPATH}/conv"
rm -rf "${WORKPATH}/txt"

tar -zcvf  ./"${name}"  "${WORKPATH}" --remove-files


