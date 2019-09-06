#!/bin/ksh -x

yymmdd=`date +%y%m%d`
LOG_FILE='load_eftrs_data'$yymmdd'.log'
OUT_FILE='eftrs.txt'
TMP_FILE 'tmp_eftrs.tst'
MSG=$YUKON/static/message.txt
HEADER_RECORD="Acct     ,Cusip    ,Description                   ,Qty,Rmd,Rsn,Acct type,Client type,Acct Name                          ,Fail Reason Text" 
echo "$HEADER_RECORD"

check_dt=`sqlplus -s $DB_USER/$DB_PASW@$DB_PATH<<!!
set heading off;
SELECT 1 FROM HOLIDAY_LST WHERE COUNTRY_CD='CA' and TRUNC(HOLIDAY_DATE) = TRUNC(SYSDATE) and JOB_NAME = 'EFTRS';
!!`
check_dt=`echo $check_dt | sed 's/ //g'`

if [[ $check_dt != 1 ]] then

sqlplus -s $DB_USER/$DB_PASW@$DB_PATH<<!!>>$LOGS/$LOG_FILE 2>&1

set serveroutput on;

whenever sqlerror exit 1

SPOOL $REPORT/tmp_eftrs.txt

set heading off
set newpage none
set feedback off
set linesize 500
set trimspool on

SELECT 
  (T.BRANCH_CD || T.ACCOUNT_CD || T.TYPE_ACCOUNT_CD)||','||
  NVL(TRIM(TS.CROSS_REFERENCE_CD),0)||','||
  TD.DESC_SEC_TXT||','||
  TRIM(TP.SHARE_TRANS_QTY)||','||
  TRIM(T.REMAINING_QTY)||','||
  '14'||','|| ' ' ||
  1||','|| '        ' ||
  1|| ','||'           '||
  'Pershing Securities Canada Limited'||','||
  ' '
  from  BPSA.TCAGE_RDM_DATA@BPSA_DB1     T,
        BPSA.TPRCHS_SALE_TRANS@BPSA_DB2 TP,
        TSEC_XREF_KEY                   TS,
        BPSA.TSECURITY_DESC@BPSA_DB1    TD
  WHERE T.BRANCH_CD             IN ('400' , '930')
  AND   T.CAGE_ACTIVITY_CD      IN ('S','U')
  AND   T.INSTR_SPCL_CAGE_CD    IN ('2','4','6')
  AND   T.SETTLEMENT_DT          =  BPSA.SF_PDATE_CA(TRUNC(SYSDATE),-11,'CA','EFTRS')
  AND   TS.SECURITY_ADP_NBR(+)   = T.SECURITY_ADP_NBR
  AND   TS.TYPE_XREF_CD          = 'CU'
  AND   TP.ACCOUNT_CD            = T.ACCOUNT_CD
  AND   TP.BRANCH_CD             = T.BRANCH_CD
  AND   TP.TYPE_ACCOUNT_CD       = T.TYPE_ACCOUNT_CD
  AND   TP.TRANS_ACCT_HIST_CD    = 'A'
  AND   TP.DEBIT_CREDIT_CD       = 'D'
  AND   TP.SECURITY_ADP_NBR      = T.SECURITY_ADP_NBR
  AND   trunc(TP.TRANSACTION_DT) = trunc(T.SETTLEMENT_DT)
  AND   trunc(TP.TRADE_DT)       = trunc(T.TRADE_DT)
  AND   (TP.BLTTR_MRKT_CD||TP.BLTTR_CPCTY_CD) = RTRIM(T.BLOTTER_CD)
  AND   TD.SECURITY_ADP_NBR      = TP.SECURITY_ADP_NBR
  AND   TD.LANGUAGE_CD           = 'E'
  AND   TD.LINE_TXT_NBR          = 1
  UNION ALL 
  select
  (T.BRANCH_CD || T.ACCOUNT_CD || T.TYPE_ACCOUNT_CD)||','||
  NVL(TRIM(TS.CROSS_REFERENCE_CD),0)||','||
  TD.DESC_SEC_TXT||','||
  TRIM(TP.SHARE_TRANS_QTY)||','||
  TRIM(T.REMAINING_QTY)||','||
  '99'||','|| ' ' ||
  1||','|| '        ' ||
  1||','|| '           '||
  'Insufficient position to deliver'
  FROM  BPSA.TCAGE_RDM_DATA@BPSA_DB1     T,
        BPSA.TPRCHS_SALE_TRANS@BPSA_DB2 TP,
        TSEC_XREF_KEY                   TS,
        BPSA.TSECURITY_DESC@BPSA_DB1    TD
  WHERE T.BRANCH_CD             IN ('400' , '930')
  AND   T.CAGE_ACTIVITY_CD      IN ('S','U')
  AND   T.INSTR_SPCL_CAGE_CD    IN ('1','3','5')
  AND   T.SETTLEMENT_DT          =  BPSA.SF_PDATE_CA(TRUNC(SYSDATE),-11,'CA','EFTRS')
  AND   TS.SECURITY_ADP_NBR(+)   = T.SECURITY_ADP_NBR
  AND   TS.TYPE_XREF_CD          = 'CU'
  AND   TP.ACCOUNT_CD            = T.ACCOUNT_CD
  AND   TP.BRANCH_CD             = T.BRANCH_CD
  AND   TP.TYPE_ACCOUNT_CD       = T.TYPE_ACCOUNT_CD
  AND   TP.TRANS_ACCT_HIST_CD    = 'A'
  AND   TP.DEBIT_CREDIT_CD       = 'C'
  AND   TP.SECURITY_ADP_NBR      = T.SECURITY_ADP_NBR
  AND   trunc(TP.TRANSACTION_DT) = trunc(T.SETTLEMENT_DT)
  AND   trunc(TP.TRADE_DT)       = trunc(T.TRADE_DT)
  AND   (TP.BLTTR_MRKT_CD||TP.BLTTR_CPCTY_CD) = RTRIM(T.BLOTTER_CD)
  AND   TD.SECURITY_ADP_NBR      = TP.SECURITY_ADP_NBR
  AND   TD.LANGUAGE_CD           = 'E'
  AND   TD.LINE_TXT_NBR          = 1;
SPOOL OFF
!!

ret_code=$?

if [[ $ret_code -ne 0 ]] then
exit 1
fi

if [[ -s $REPORT/tmp_eftrs.txt ]] then
   echo "$HEADER_RECORD" > $REPORT/eftrs.txt
   cat $REPORT/tmp_eftrs.txt >> $REPORT/eftrs.txt
cat $REPORT/eftrs.txt | cut -d, -f-6,9- >> $REPORT/eftrs_mail.txt

if [[ "$ENV" = 'prod' ]] then
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice - Fail Record Found" -tbstager@pershing.com -i$REPORT/eftrs_mail.txt
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice - Fail Record Found" -tmthoufeek@inautix.co.in -i$REPORT/eftrs_mail.txt
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice - Fail Record Found" -trbeharry@pershing.com -i$REPORT/eftrs_mail.txt
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice - Fail Record Found" -talora@pershing.com -i$REPORT/eftrs_mail.txt
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice - Fail Record Found" -traquel.andrade@bnymellon.com -i$REPORT/eftrs_mail.txt
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice - Fail Record Found" -tryan.wagner@pershing.com -i$REPORT/eftrs_mail.txt
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice - Fail Record Found" -tBDelAguila@pershing.com -i$REPORT/eftrs_mail.txt
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice - Fail Record Found" -tNatalia.Mohl@bnymellon.com -i$REPORT/eftrs_mail.txt
fi
else
   echo "No data available for Extended Trade Fail Report" >>$LOGS/$LOG_FILE
if [[ "$ENV" = 'prod' ]] then
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice" -tbstager@pershing.com -i$LOGS/$LOG_FILE
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice" -tmthoufeek@inautix.co.in -i$LOGS/$LOG_FILE
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice" -trbeharry@pershing.com -i$LOGS/$LOG_FILE
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice" -talora@pershing.com -i$LOGS/$LOG_FILE
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice" -traquel.andrade@bnymellon.com -i$LOGS/$LOG_FILE
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice" -tryan.wagner@pershing.com -i$LOGS/$LOG_FILE
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice" -tBDelAguila@pershing.com -i$LOGS/$LOG_FILE
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice" -tNatalia.Mohl@bnymellon.com -i$LOGS/$LOG_FILE
fi
fi

else
holiday_date=`sqlplus -s $DB_USER/$DB_PASW@$DB_PATH<<!!
set heading off;
SELECT HOLIDAY_DATE FROM HOLIDAY_LST WHERE COUNTRY_CD='CA' and TRUNC(HOLIDAY_DATE) = TRUNC(SYSDATE)
AND JOB_NAME = 'EFTRS';
!!`
echo "$0 exiting.....$holiday_date is a Canadian holiday" >> $LOGS/$LOG_FILE
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice" -tbstager@pershing.com -i$LOGS/$LOG_FILE
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice" -tmthoufeek@inautix.co.in -i$LOGS/$LOG_FILE
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice" -trbeharry@pershing.com -i$LOGS/$LOG_FILE
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice" -talora@pershing.com -i$LOGS/$LOG_FILE
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice" -traquel.andrade@bnymellon.com -i$LOGS/$LOG_FILE
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice" -tryan.wagner@pershing.com -i$LOGS/$LOG_FILE
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice" -tBDelAguila@pershing.com -i$LOGS/$LOG_FILE
/prod/bin/iceemail -fgssit@pershing.com -s"EFTR Notice" -tNatalia.Mohl@bnymellon.com -i$LOGS/$LOG_FILE
fi

rm -rf $REPORT/tmp_eftrs.txt

if [[ "$ENV" = 'prod' ]] then
FTP_DIR=/prod/home/bpscaftp/
FTP_ARCHIVE=/prod/home/bpscaftp/cds_21
if ls $FTP_DIR/cds.f21* &> /dev/null; then
mv $FTP_DIR/cds.f21* $FTP_ARCHIVE/
fi
rm -rf `find $FTP_ARCHIVE/* -mtime +60`
fi

