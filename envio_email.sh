#!/bin/ksh

#  Este programa envia um e-mail para o destinário obtido em uma tabela no banco de dados
#  A variável MAIL_USERNAME recebe o e-mail obtido do Banco de dados.
#  Este arquivo eh convertido para DOS e tranmitido anexado ao e-mail

# Variaveis utilizadas:
#  MAIL_LOCAL_FILE - recebe o nome do arquivo que sera enviado - eh definido antes de chamar a funcao
#  MAIL_LOCAL_DIR - recebe o nome do diretorio que sera enviado - eh definido antes de chamar a funcao
#  DOSFILE - nome do arquivo de DOS - temporario
#  UUEFILE - nome do arquivo de UUE ("atachado") - temporario
#  SQLUSER - Login do usuário do BD
#  SQLPAS  - Senha do usuário
#  DS_DATABASE - Nome do banco de dados

WORKDIR=relatorios/FF07/work
READYDIR=relatorios/FF07/ready
SENDREADYDIR=relatorios/FF07/sendready
ERRORDIR=relatorios/FF07/error
TMPDIR=relatorios/FF07/tmp
LOGDIR=relatorios/FF07/log

LOGCODE="rpt_ff07_report"
RUNDATE=`date '+%Y%m%d_%H%M%S'`
LOGNAME="${LOGCODE}_${RUNDATE}.log"
LOGFILE=$LOGDIR/$LOGNAME
dataini=`date '+%d/%m/%Y %H:%M:%S'`
VPID=$$

cat /dev/null > $LOGFILE
if [ $? -ne 0 ] ; then
 echo "ERR_MSG> Impossivel criar o arquivo $LOGFILE"
 ARQ_LOG=""
 exit 1
fi

echo "=================================================================================" >> $LOGFILE
echo "ARQUIVO DE LOG" >> $LOGFILE
echo "envio_email.sh" >> $LOGFILE
echo "=================================================================================" >> $LOGFILE
echo "Nome do Log      : $LOGNAME" >> $LOGFILE
echo "Programa         : $0" >> $LOGFILE
echo "Versao           : 1.0" >> $LOGFILE
echo "PID              : $VPID" >> $LOGFILE
echo "Autor            : Carlos Ferreira" >> $LOGFILE
echo "Data/Hora inicio : $dataini" >> $LOGFILE
echo "=================================================================================" >> $LOGFILE

# Copia o arquivo que está no diretório ready para o diretório work
cp $READYDIR/* $WORKDIR
MAIL_LOCAL_DIR=$WORKDIR
MAIL_LOCAL_FILE=`ls -rt $WORKDIR | grep "dados.txt" | tail -1`

################################################################
# Inicio do Bloco SQL                                          #
################################################################
MAIL_USER=`sqlplus -s <<fim
$SQLUSER/$SQLPASS@$DS_DATABASE
SET HEAD OFF;
SET FEEDBACK OFF;
SET TERMOUT OFF;
SET NEWPAGE NONE;
SET PAGESIZE 20;
SET ECHO OFF;
SET SHOWMODE OFF;
SET VERIFY OFF;

select USER_EMAIL from rpt_distrib_list
where rpt_code = 'FF07';

EXIT;
fim`

RC=$?
if [ $RC -ne 0 ]
then
   echo "\nERR_010> Problemas ao consultar a tabela rpt_distrib_list " >> $LOGFILE
   exit 1   
fi
# Fim do Bloco SQL

DOSFILE=$TMPDIR/MAIL.DOSFILE.$MAIL_LOCAL_FILE.`date '+%Y%m%d%H%M%S'`.tmp
UUEFILE=$TMPDIR/MAIL.UUEFILE.$MAIL_LOCAL_FILE.`date '+%Y%m%d%H%M%S'`.tmp
SUBJECT="Relatório FF07 - `date '+%d/%m/%Y %H:%M:%S'`"

# TRANSF_EMAIL inicia com 1. Se chegar ao final sem problemas, ele eh alterado para 0.
TRANSF_EMAIL=1

echo "DEBUG_`date '+%Y%m%d%H%M%S'`: Convertendo $MAIL_LOCAL_DIR/$MAIL_LOCAL_FILE arquivo formato UNIX para formato DOS" >> $LOGFILE
echo "" > $DOSFILE
unix2dos -ascii $MAIL_LOCAL_DIR/$MAIL_LOCAL_FILE $DOSFILE 2> /dev/null

if [ $? -ne 0 ]
then
   echo "ERR_012>: Erro na conversao de $MAIL_LOCAL_DIR/$MAIL_LOCAL_FILE do formato UNIX para DOS" >> $LOGFILE
   RetCode=1
   return
fi
mv $DOSFILE $MAIL_LOCAL_DIR/$MAIL_LOCAL_FILE

echo "DEBUG_`date '+%Y%m%d%H%M%S'`: Convertendo arquivo $DOSFILE para formato attach" >> $LOGFILE

echo "Sr(a), Segue anexo os dados do relatório FF07" > $UUEFILE
echo "" >> $UUEFILE
uuencode $MAIL_LOCAL_DIR/$MAIL_LOCAL_FILE $MAIL_LOCAL_FILE >> $UUEFILE

RC=$?
if [ $RC -ne 0 ]
then
   echo "ERR_013> Erro na conversao de $DOSFILE (com nome $MAIL_LOCAL_FILE) para formato attach" >> $LOGFILE
   RetCode=1
   return
fi

echo "DEBUG_`date '+%Y%m%d%H%M%S'`: Enviando o arquivo $UUEFILE no formato attach para $MAIL_USER"  >> $LOGFILE
mailx -s "$SUBJECT" $MAIL_USER < $UUEFILE >> $LOGFILE

if [ $? -ne 0 ]
then
   echo "ERR_014> Erro ao enviar o arquivo $UUEFILE ($MAIL_LOCAL_FILE.txt) para " $MAIL_USER >> $LOGFILE
   RetCode=1
   return
fi

# Se chegou neste ponto, a transmissao foi com sucesso
TRANSF_EMAIL=0
echo "DEBUG_`date '+%Y%m%d%H%M%S'`: E-mail enviado com sucesso para $MAIL_USER"  >> $LOGFILE

# Excluindo arquivos
rm $DOSFILE 2> /dev/null
rm $UUEFILE
cp $READYDIR/* $SENDREADYDIR
rm $READYDIR/*
rm $WORKDIR/*

exit 0