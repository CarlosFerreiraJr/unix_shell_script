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
