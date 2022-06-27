# unix_shell_script
Programas e funções em UNIX Shell Scripting

### Rotina de Envio de E-mail com arquivo anexo
```
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
```

### Rotina de atualização de Base Dados
Esse script tem por objetivo executar um procedure na base dados.
O script lê os dados para conexão "usuário/senha@banco_de_dados" que estão dentro de um arquivo no UNIX.

```
#!/bin/ksh

# Função log_erro - Escreve mensagem de ERRO no log 
log_erro()
{
  echo "ERRO__`date '+%Y%m%d_%H%M%S'`: $*"
}

# Função log_aviso - Escreve Mensagem de Aviso no log 
log_aviso()
{
  echo "AVISO_`date '+%Y%m%d_%H%M%S'`: $*"
}

# Função log_info - Escreve mensagem Informativa no log 
log_info()
{
  echo "INFO__`date '+%Y%m%d_%H%M%S'`: $*"
}

# Função rotina_erro - Escreve mensagem de erro no log e finaliza o programa com código de erro = 1
rotina_erro()
{
  log_erro "Ocorreu um erro durante a execucao do processo. Processo abortado."
  fim_processo 1
}

# Função deleta_arq_tmp - Rotina de delecao dos arquivos temporarios gerados pelo processo
deleta_arq_tmp()
{
  trap '' ERR

  test -f "$ARQTMP" && rm "$ARQTMP" 2> /dev/null
  test -f "$ARQ_QUERY" && rm "$ARQ_QUERY" 2> /dev/null
  test -f "$RESULT_QUERY" && rm "$RESULT_QUERY" 2> /dev/null  
  test -f "$ARQLST" && rm "$ARQLST" 2> /dev/null
  test -f "$ARQAUX" && rm "$ARQAUX" 2> /dev/null
  test -f "$ARQMAIL" && rm "$ARQMAIL" 2> /dev/null  

  trap 'rotina_erro' ERR 
}

# Função fim_processo - Rotina de encerramento do processo 
fim_processo()
{
  RETCODE=$1
  ENDDATE=`date '+%d/%m/%Y %H:%M:%S'`

  if [ $RETCODE -eq 0 ]
  then
     log_info "Processo completado com sucesso - Status $RETCODE "
  else
     log_info "Processo completado com ERRO - Status $RETCODE "
  fi

  log_info "Processo: $NOMEPROCESSO -> Data de Termino: $ENDDATE"

  deleta_arq_tmp

  exit $RETCODE
}

# Função obtem_diretorios - Obtém o diretório de trabalho do ambiente
obtem_diretorios()
{
CONN=$(cat $ARQ_CON 2> /dev/null)
RET1=$?

if [[ $RET1 -ne 0 ]]
then
   log_erro "Ocorreu um erro durante ao obter os dados para conexao!"
   fim_processo 1
fi

touch $RESULT_QUERY 

log_info "Obtendo o diretório de trabalho do ambiente"
sqlplus -s <<-fim >> $RESULT_QUERY
     $CONN
     whenever sqlerror exit 1
     whenever oserror exit 1
     set echo off
     set feedback off
     set verify off
     set heading off
     select absolute_dir from tb_ambiente;
     exit
fim

  RET=$?

  if [ $RET -ne 0 ]
  then
     log_erro "Ocorreu um erro ao obter o diretório de trabalho"
     log_erro "$(grep 'ORA' $RESULT_QUERY) \n"
     log_info "Log de Erro:"
     cat $RESULT_QUERY | while read LIN
     do
        log_info "$LIN"        
     done

     test -f "$ARQ_QUERY" && rm $ARQ_QUERY 2> /dev/null

     fim_processo 1
  else      
     cat $RESULT_QUERY | while read LIN
     do
        ABSOLUTE_DIR="$LIN"        
     done  
     
     log_info "Diretório de trabalho: [$ABSOLUTE_DIR]"
     
  fi

  test -f "$ARQ_QUERY" && rm $ARQ_QUERY 2> /dev/null  
}

# Função executa_atualizacao - Rotina de atualização da base de dados
executa_atualizacao()
{	
CONN=$(cat $ARQ_CON 2> /dev/null)
RET1=$?

if [[ $RET1 -ne 0 ]]
then
   log_erro "Ocorreu um erro durante ao obter os dados para conexao!"
   fim_processo 1
fi

log_info "Executando a Procedure atualiza_dados"
sqlplus -s $CONN <<-fim >> $RESULT_QUERY
     whenever sqlerror exit 1
     whenever oserror exit 1
     set echo off
     set feedback off
     set verify off
     set heading off
     set serveroutput on   
                                               
BEGIN  
 atualiza_dados_cad('${V_INSTANCIA}');                                                           
                                                                                  
EXCEPTION                                                                         
  WHEN OTHERS THEN  	                                                            
    DBMS_OUTPUT.PUT_LINE('Cod. Erro:' || SQLCODE  );                              
    DBMS_OUTPUT.PUT_LINE('Msg. Erro:' || SQLERRM  );                              
    RETURN;	                                                                      
END;                                                                              
/  
fim
    
RET=$?

  if [ $RET -ne 0 ]
  then
     log_erro "Ocorreu um erro durante na execução do processo ! "
     log_erro "$(grep 'ORA' $RESULT_QUERY) \n"
     log_info "Log de Erro:"
     cat $RESULT_QUERY | while read LIN
     do
        log_info "$LIN"
     done

     test -f "$ARQ_QUERY" && rm $ARQ_QUERY 2> /dev/null

     fim_processo 1
  fi

  test -f "$ARQ_QUERY" && rm $ARQ_QUERY 2> /dev/null  
  
  log_info "Procedure atualiza_dados_cad executada com sucesso para a instância ${V_INSTANCIA}!"
}


# Variáveis Globais
V_INSTANCIA=$1
PROCESSO="atualiza_dados_cad"
ARQLOG="${DIRLOG}/${PROCESSO}_$(date '+%Y%m%d%H%M%S').log"
DIR_TMP="$DIRDATA/tmp"
ARQTMP="${DIR_TMP}/${PROCESSO}.tmp"
ARQLST="${DIR_TMP}/${PROCESSO}.lst"
ARQAUX="${DIR_TMP}/${PROCESSO}.aux"
ARQ_CON="${DIRBIN}/conexao.txt"
RESULT_QUERY="${DIR_TMP}/${PROCESSO}.res"
ABSOLUTE_DIR=""
ERRO=0
OK=0
RETCODERRO=0
ARQ_DATE=`date '+%y%m%d'`
ARQ_HORA=`date '+%H%M%S'`

# Direcionando a stdout e stderr para o log
exec >> $ARQLOG 2>&1
set +x

# Trata interrupcao com sinal de erro
trap 'rotina_erro' ERR 

# Rotina principal 
log_info "Processo: $NOMEPROCESSO -> Data de inicio: `date '+%d/%m/%Y %H:%M:%S'` "
log_info "Sintaxe: $0 $*"

# Rotina de testes de variaveis de ambiente 
test -z "$DIRDATA" && log_erro "Variavel de ambiente DIRDATA invalida !" && ERRO=1
test ! -d "$DIRDATA" && log_erro "O diretorio $DIRDATA nao existe !" && ERRO=1
test ! -w "$DIRDATA" && log_erro "Voce nao tem direito de gravacao no diretorio $DIRDATA !" && ERRO=1

test -z "$DIRLOG" && log_erro "Variavel de ambiente DIRLOG invalida !" && ERRO=1
test ! -d "$DIRLOG" && log_erro "O diretorio $DIRLOG nao existe !" && ERRO=1
test ! -w "$DIRLOG" && log_erro "Voce nao tem direito de gravacao no diretorio $DIRLOG !" && ERRO=1

test -z "$DIRBIN" && log_erro "Variavel de ambiente DIRBIN invalida !" && ERRO=1
test ! -d "$DIRBIN" && log_erro "O diretorio $DIRBIN nao existe !" && ERRO=1
test ! -w "$DIRBIN" && log_erro "Voce nao tem direito de gravacao no diretorio $DIRBIN !" && ERRO=1

test ! -d "$DIR_TMP" && log_erro "O diretorio $DIR_TMP nao existe !" && ERRO=1
test ! -w "$DIR_TMP" && log_erro "Voce nao tem direito de gravacao no diretorio $DIR_TMP !" && ERRO=1

if [ $ERRO -eq 1 ]
then
   fim_processo 1
fi

trap '' ERR

deleta_arq_tmp

trap '' ERR

obtem_diretorios

trap '' ERR

executa_atualizacao

fim_processo OK
```
