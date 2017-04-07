REMASK.PS1:
###########################################################################
#
# NAME: remask.ps1

#
# COMMENT: Provided As Is
# DESCRIPTION:
# This script generates the commands to unmask FC targets and mask GM targets
# in the event of an actual DR event.  Key variables that need to be custom-
# ized are the DRhostname, Flashcopy consistency group and the Global Mirror
# consistency group.
#
# VERSION HISTORY:
# 1.0 11/26/2012 - Initial release
#
###########################################################################
$DRhostname='DRhost01'
$TGTSVC='lbsv7ku01'
$fcConsistgrp='fcgrp1'
$rcConsistgrp='gmgrp1'
$plinkexe='c:\putty\plink.exe'
#
# First set of commands unmask FC targets from the DR host.
#
$lsfcmapcmd='lsfcmap -filtervalue group_name=${fcConsistgrp} -nohdr -delim :'
$plinkcmd=${plinkexe} + " " + 'admin@' + ${TGTSVC} + " " + ${lsfcmapcmd}
$lsfcmapout=Invoke-Expression -command ${plinkcmd}
foreach($arrayRow in $lsfcmapout){
  $arrayElements=$arrayRow.Split(":");
  $vdisk=$arrayElements[5];
  echo "rmvdiskhostmap -host $DRhostname $vdisk";
}

#
# Second set of commands masks GM targets to the DR host.
#
$lsrcrelcmd='lsrcrelationship -filtervalue consistency_group_name=${rcConsistgrp} -nohdr -delim :'
$plinkcmd=${plinkexe} + " " + 'admin@' + ${TGTSVC} + " " + ${lsrcrelcmd}
foreach($arrayRow in cat ../lsvdisk){
  $arrayElements=$arrayRow.Split(":");
  $vdisk=$arrayElements[9];
  echo "mkvdiskhostmap -host $DRhostname $vdisk";
}


SCRIPTGEN.PS1:
###########################################################################
#
# NAME: scriptgen.ps1
#
# COMMENT: Provided As Is.
#
# DESCRIPTION:
# This script takes a list of VDISKs (that have not been commented out)
# from the SRCSVC and generates SVC command files that will create the
# following:
#  -mktgtvdisks.cmd: Global Mirror Target Volumes on the TGTSVC
#  -mkchgvol.cmd: Change Volumes on both systems
#  -mkrcrelationship.cmd: Global Mirror RC relationships with change volumes
#  -mkfcmap.cmd: Flashcopy relationships
#
# The naming convention is that the source volume will have a _S to
# indicate it is a source volume.  It may also be _SR to indicate 
# that it is a source volume that is raw device mapped in VMWare.
# 
# To obtain the correct information on the source IO Group and MDG
# generate an lsvdisk output with lsvdisk -delim : -bytes and put in
# same directory.
# 
# VERSION HISTORY:
# 1.0 11/26/2012 - Initial release
# 1.1 1/8/2013 - removed sed and grep functions and replaced with Powershell equivalents
###########################################################################

$RUNNINGDIR='c:\Documents and Settings\Administrator\My Documents\PSExamples'
$VDISKLIST="${RUNNINGDIR}\inputfile"
$LSVDISKLIST="${RUNNINGDIR}\lsvdisk"
$SRCSVC='CAESVC01'
$TGTSVC='DC2SVC01'
$TGTMDG='DS8800_300_15K'
$GMCONSISTGRP='SQLGRPGM'
$FCCONSISTGRP='SQLGRPFC'
$GMCOUNTERSTART=2
$FCCOUNTERSTART=2
$GMRCRELPREFIX='rcsqlrel'
$FCMAPPREFIX='fcsqlrel'
$CYCLINGPERIOD='90'

echo "working on mktgtvdisks..."
# Generate GM target volumes and GM target volume FC targets on
# remotecluster from source file. 
foreach(${SRCVOL} in get-content ${VDISKLIST}|Select-String ^# -notmatch){
  $TGTVOL=echo ${SRCVOL}| %{$_ -replace '_S','_T'};
  $arrayRow=grep :${SRCVOL}: ${LSVDISKLIST};
  $arrayElements=$arrayRow.Split(":");
  $VOLSIZE=$arrayElements[7];
#
# Just grabbed IO Group from source definition.  Don't know how to grab last
# digit of iteration number to the left of _ with Powershell.
#
  $VOLIOG=$arrayElements[2];
  echo "plink ${TGTSVC} -l admin mkvdisk -mdiskgrp ${TGTMDG} -iogrp ${VOLIOG} -vtype striped -size ${VOLSIZE} -unit b -name ${TGTVOL}";
  echo "plink ${TGTSVC} -l admin mkvdisk -mdiskgrp ${TGTMDG} -iogrp ${VOLIOG} -vtype striped -size ${VOLSIZE} -unit b -name ${TGTVOL}F";
}
echo "======================================================================"

# Generate space efficient or thinly provisioned change volumes
# on both clusters using input file and lsvdisk output.  We are
# assuming that the change volumes will go in the same MDGs as
# the global mirror source and target volumes.

foreach(${SRCVOL} in get-content ${VDISKLIST}|Select-String ^# -notmatch){
  $TGTVOL=echo ${SRCVOL}|%{$_ -replace '_S','_T'};
  $arrayRow=grep :${SRCVOL}: ${LSVDISKLIST};
  $arrayElements=$arrayRow.Split(":");
  $SRCMDG=$arrayElements[6];
#
# Used same IO Group for source and target
#
  $SRCIOG=$arrayElements[2];
  $TGTIOG=$SRCIOG;
  $VOLSIZE=$arrayElements[7];
  echo "plink ${SRCSVC} -l admin mkvdisk -mdiskgrp ${SRCMDG} -iogrp ${SRCIOG} -vtype striped -size ${VOLSIZE} -unit b -rsize 0% -autoexpand -name ${SRCVOL}C";
  echo "plink ${TGTSVC} -l admin mkvdisk -mdiskgrp ${TGTMDG} -iogrp ${TGTIOG} -vtype striped -size ${VOLSIZE} -unit b -rsize 0% -autoexpand -name ${TGTVOL}C";
} 
echo "======================================================================"
# Ensure GM consistency group exists.
echo "Before running mkrcrelationship commands, run the following command:"
echo "mkrcconsistgrp -name ${GMCONSISTGRP}"
echo ''
echo ''
echo "working on mkrcrelationship..."
# Generate global mirror remote copy relationships from vdisk list
# and associate change volumes.
$COUNTER=${GMCOUNTERSTART}
foreach(${SRCVOL} in get-content ${VDISKLIST}|Select-String ^# -notmatch){
  $TGTVOL=echo ${SRCVOL}|%{$_ -replace '_S','_T'};
# Pad number with leading zeros to make it consistent 3 digit.
  $COUNTNUM="{0:D3}" -f ${COUNTER}
  $GMNAME="${GMRCRELPREFIX}${COUNTNUM}"
  echo "plink ${SRCSVC} -l admin mkrcrelationship -master ${SRCVOL} -aux ${TGTVOL}  -cluster ${TGTSVC} -consistgrp ${GMCONSISTGRP} -global -name ${GMNAME} -cyclingmode multi "
  echo "plink ${SRCSVC} -l admin chrcrelationship -masterchange ${SRCVOL}C ${GMNAME}"
  echo "plink ${TGTSVC} -l admin chrcrelationship -auxchange ${TGTVOL}C ${GMNAME}"
  $COUNTER=$COUNTER+1
}
echo "======================================================================"

# Make sure the cycling period is correct.
echo "After running mkrcrelationship commands, run the following command:"
echo "chrcconsistgrp -cyclingperiodseconds ${CYCLINGPERIOD}"
echo ''
echo ''
# Generate FC maps from VDISK list.
# Ensure FC consistency group exists.
echo "Before running mkrfcmap commands, run the following command:"
echo "mkfcconsistgrp -name ${FCCONSISTGRP}"
echo ''
echo ''
echo "working on mkfcmap..."
$COUNTER=${FCCOUNTERSTART}
foreach(${SRCVOL} in get-content ${VDISKLIST}|Select-String ^# -notmatch){
  $TGTVOL=echo ${SRCVOL}|%{$_ -replace '_S','_T'};
  $COUNTNUM="{0:D3}" -f ${COUNTER}
  $FCNAME="${FCMAPPREFIX}${COUNTNUM}"
  echo "plink ${TGTSVC} -l admin mkfcmap -source ${TGTVOL} -target ${TGTVOL}F -consistgrp ${FCCONSISTGRP} -name ${FCNAME} -copyrate 100 -cleanrate 100"
  $COUNTER=$COUNTER+1
}
echo "======================================================================"


INPUTFILE:
PSQLNNH151_63_SR
PSQLNNH151_36_SR
PSQLNNH151_49_SR
PSQLNNH151_35_SR
PSQLNNH151_38_SR
PSQLNNH151_37_SR
#PSQLNNH151_107_SR
#PSQLNNH151_100_SR
#PSQLNNH151_98_SR
#PSQLNNH151_50_SR
#PSQLNNH151_67_SR
#PSQLNNH151_91_SR
#PSQLNNNH303_12_SR
#PSQLNNNH303_14_SR
#PSQLNNNH303_13_SR
#PSQLNNNH303_26_SR
#PSQLNNNH303_31_SR
#PSQLNNNH303_40_SR
#PSQLNNNH002_09_SR
#PSQLCNNH001_02_SR
#PSQLNBNH206_07_SR
#PSQLNCNH204_04_SR
#PSQLCEH283_C08_S
#PSQLCEH283_C25_S
#PSQLCEH283_C26_S
#PSQLCEH283_C31_S
#PSQLCEH283_C47_S
#PSQLCEH285_20_S
#PSQLCEH285_08_S
#PSQLCEH286_17_S
#PSQLCEH286_08_S
PSQLCHEH253_C19_S
PSQLCHEH253_C12_S


OUTPUTFILE:
working on mktgtvdisks...
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 0 -vtype striped -size 2093796556800 -unit b -name PSQLNNH151_63_TR
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 0 -vtype striped -size 2093796556800 -unit b -name PSQLNNH151_63_TRF
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 0 -vtype striped -size 429496729600 -unit b -name PSQLNNH151_36_TR
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 0 -vtype striped -size 429496729600 -unit b -name PSQLNNH151_36_TRF
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 1 -vtype striped -size 912680550400 -unit b -name PSQLNNH151_49_TR
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 1 -vtype striped -size 912680550400 -unit b -name PSQLNNH151_49_TRF
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 1 -vtype striped -size 32212254720 -unit b -name PSQLNNH151_35_TR
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 1 -vtype striped -size 32212254720 -unit b -name PSQLNNH151_35_TRF
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 0 -vtype striped -size 322122547200 -unit b -name PSQLNNH151_38_TR
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 0 -vtype striped -size 322122547200 -unit b -name PSQLNNH151_38_TRF
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 1 -vtype striped -size 901943132160 -unit b -name PSQLNNH151_37_TR
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 1 -vtype striped -size 901943132160 -unit b -name PSQLNNH151_37_TRF
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 0 -vtype striped -size 429496729600 -unit b -name PSQLCHEH253_C19_T
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 0 -vtype striped -size 429496729600 -unit b -name PSQLCHEH253_C19_TF
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 1 -vtype striped -size 950261514240 -unit b -name PSQLCHEH253_C12_T
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 1 -vtype striped -size 950261514240 -unit b -name PSQLCHEH253_C12_TF
======================================================================
plink CAESVC01 -l admin mkvdisk -mdiskgrp T02G02DS8800SS -iogrp 0 -vtype striped -size 2093796556800 -unit b -rsize 0% -autoexpand -name PSQLNNH151_63_SRC
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 0 -vtype striped -size 2093796556800 -unit b -rsize 0% -autoexpand -name PSQLNNH151_63_TRC
plink CAESVC01 -l admin mkvdisk -mdiskgrp T02G02DS8800SS -iogrp 0 -vtype striped -size 429496729600 -unit b -rsize 0% -autoexpand -name PSQLNNH151_36_SRC
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 0 -vtype striped -size 429496729600 -unit b -rsize 0% -autoexpand -name PSQLNNH151_36_TRC
plink CAESVC01 -l admin mkvdisk -mdiskgrp T02G02DS8800SS -iogrp 1 -vtype striped -size 912680550400 -unit b -rsize 0% -autoexpand -name PSQLNNH151_49_SRC
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 1 -vtype striped -size 912680550400 -unit b -rsize 0% -autoexpand -name PSQLNNH151_49_TRC
plink CAESVC01 -l admin mkvdisk -mdiskgrp T01G01DS8800SS -iogrp 1 -vtype striped -size 32212254720 -unit b -rsize 0% -autoexpand -name PSQLNNH151_35_SRC
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 1 -vtype striped -size 32212254720 -unit b -rsize 0% -autoexpand -name PSQLNNH151_35_TRC
plink CAESVC01 -l admin mkvdisk -mdiskgrp T02G02DS8800SS -iogrp 0 -vtype striped -size 322122547200 -unit b -rsize 0% -autoexpand -name PSQLNNH151_38_SRC
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 0 -vtype striped -size 322122547200 -unit b -rsize 0% -autoexpand -name PSQLNNH151_38_TRC
plink CAESVC01 -l admin mkvdisk -mdiskgrp T02G02DS8800SS -iogrp 1 -vtype striped -size 901943132160 -unit b -rsize 0% -autoexpand -name PSQLNNH151_37_SRC
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 1 -vtype striped -size 901943132160 -unit b -rsize 0% -autoexpand -name PSQLNNH151_37_TRC
plink CAESVC01 -l admin mkvdisk -mdiskgrp T02G02DS8800SS -iogrp 0 -vtype striped -size 429496729600 -unit b -rsize 0% -autoexpand -name PSQLCHEH253_C19_SC
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 0 -vtype striped -size 429496729600 -unit b -rsize 0% -autoexpand -name PSQLCHEH253_C19_TC
plink CAESVC01 -l admin mkvdisk -mdiskgrp T02G02DS8800SS -iogrp 1 -vtype striped -size 950261514240 -unit b -rsize 0% -autoexpand -name PSQLCHEH253_C12_SC
plink DC2SVC01 -l admin mkvdisk -mdiskgrp DS8800_300_15K -iogrp 1 -vtype striped -size 950261514240 -unit b -rsize 0% -autoexpand -name PSQLCHEH253_C12_TC
======================================================================
Before running mkrcrelationship commands, run the following command:
mkrcconsistgrp -name SQLGRPGM
working on mkrcrelationship...
plink CAESVC01 -l admin mkrcrelationship -master PSQLNNH151_63_SR -aux PSQLNNH151_63_TR  -cluster DC2SVC01 -consistgrp SQLGRPGM -global -name rcsqlrel2 -cyclingmode multi 
plink CAESVC01 -l admin chrcrelationship -masterchange PSQLNNH151_63_SRC rcsqlrel2
plink DC2SVC01 -l admin chrcrelationship -auxchange PSQLNNH151_63_TRC rcsqlrel2
plink CAESVC01 -l admin mkrcrelationship -master PSQLNNH151_36_SR -aux PSQLNNH151_36_TR  -cluster DC2SVC01 -consistgrp SQLGRPGM -global -name rcsqlrel21 -cyclingmode multi 
plink CAESVC01 -l admin chrcrelationship -masterchange PSQLNNH151_36_SRC rcsqlrel21
plink DC2SVC01 -l admin chrcrelationship -auxchange PSQLNNH151_36_TRC rcsqlrel21
plink CAESVC01 -l admin mkrcrelationship -master PSQLNNH151_49_SR -aux PSQLNNH151_49_TR  -cluster DC2SVC01 -consistgrp SQLGRPGM -global -name rcsqlrel211 -cyclingmode multi 
plink CAESVC01 -l admin chrcrelationship -masterchange PSQLNNH151_49_SRC rcsqlrel211
plink DC2SVC01 -l admin chrcrelationship -auxchange PSQLNNH151_49_TRC rcsqlrel211
plink CAESVC01 -l admin mkrcrelationship -master PSQLNNH151_35_SR -aux PSQLNNH151_35_TR  -cluster DC2SVC01 -consistgrp SQLGRPGM -global -name rcsqlrel2111 -cyclingmode multi 
plink CAESVC01 -l admin chrcrelationship -masterchange PSQLNNH151_35_SRC rcsqlrel2111
plink DC2SVC01 -l admin chrcrelationship -auxchange PSQLNNH151_35_TRC rcsqlrel2111
plink CAESVC01 -l admin mkrcrelationship -master PSQLNNH151_38_SR -aux PSQLNNH151_38_TR  -cluster DC2SVC01 -consistgrp SQLGRPGM -global -name rcsqlrel21111 -cyclingmode multi 
plink CAESVC01 -l admin chrcrelationship -masterchange PSQLNNH151_38_SRC rcsqlrel21111
plink DC2SVC01 -l admin chrcrelationship -auxchange PSQLNNH151_38_TRC rcsqlrel21111
plink CAESVC01 -l admin mkrcrelationship -master PSQLNNH151_37_SR -aux PSQLNNH151_37_TR  -cluster DC2SVC01 -consistgrp SQLGRPGM -global -name rcsqlrel211111 -cyclingmode multi 
plink CAESVC01 -l admin chrcrelationship -masterchange PSQLNNH151_37_SRC rcsqlrel211111
plink DC2SVC01 -l admin chrcrelationship -auxchange PSQLNNH151_37_TRC rcsqlrel211111
plink CAESVC01 -l admin mkrcrelationship -master PSQLCHEH253_C19_S -aux PSQLCHEH253_C19_T  -cluster DC2SVC01 -consistgrp SQLGRPGM -global -name rcsqlrel2111111 -cyclingmode multi 
plink CAESVC01 -l admin chrcrelationship -masterchange PSQLCHEH253_C19_SC rcsqlrel2111111
plink DC2SVC01 -l admin chrcrelationship -auxchange PSQLCHEH253_C19_TC rcsqlrel2111111
plink CAESVC01 -l admin mkrcrelationship -master PSQLCHEH253_C12_S -aux PSQLCHEH253_C12_T  -cluster DC2SVC01 -consistgrp SQLGRPGM -global -name rcsqlrel21111111 -cyclingmode multi 
plink CAESVC01 -l admin chrcrelationship -masterchange PSQLCHEH253_C12_SC rcsqlrel21111111
plink DC2SVC01 -l admin chrcrelationship -auxchange PSQLCHEH253_C12_TC rcsqlrel21111111
======================================================================
After running mkrcrelationship commands, run the following command:
chrcconsistgrp -cyclingperiodseconds 90
Before running mkrfcmap commands, run the following command:
mkfcconsistgrp -name SQLGRPFC
working on mkfcmap...
plink DC2SVC01 -l admin mkfcmap -source PSQLNNH151_63_TR -target PSQLNNH151_63_TRF -consistgrp SQLGRPFC -name fcsqlrel2 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source PSQLNNH151_36_TR -target PSQLNNH151_36_TRF -consistgrp SQLGRPFC -name fcsqlrel21 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source PSQLNNH151_49_TR -target PSQLNNH151_49_TRF -consistgrp SQLGRPFC -name fcsqlrel211 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source PSQLNNH151_35_TR -target PSQLNNH151_35_TRF -consistgrp SQLGRPFC -name fcsqlrel2111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source PSQLNNH151_38_TR -target PSQLNNH151_38_TRF -consistgrp SQLGRPFC -name fcsqlrel21111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source PSQLNNH151_37_TR -target PSQLNNH151_37_TRF -consistgrp SQLGRPFC -name fcsqlrel211111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLNNH151_107_TR -target #PSQLNNH151_107_TRF -consistgrp SQLGRPFC -name fcsqlrel2111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLNNH151_100_TR -target #PSQLNNH151_100_TRF -consistgrp SQLGRPFC -name fcsqlrel21111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLNNH151_98_TR -target #PSQLNNH151_98_TRF -consistgrp SQLGRPFC -name fcsqlrel211111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLNNH151_50_TR -target #PSQLNNH151_50_TRF -consistgrp SQLGRPFC -name fcsqlrel2111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLNNH151_67_TR -target #PSQLNNH151_67_TRF -consistgrp SQLGRPFC -name fcsqlrel21111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLNNH151_91_TR -target #PSQLNNH151_91_TRF -consistgrp SQLGRPFC -name fcsqlrel211111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLNNNH303_12_TR -target #PSQLNNNH303_12_TRF -consistgrp SQLGRPFC -name fcsqlrel2111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLNNNH303_14_TR -target #PSQLNNNH303_14_TRF -consistgrp SQLGRPFC -name fcsqlrel21111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLNNNH303_13_TR -target #PSQLNNNH303_13_TRF -consistgrp SQLGRPFC -name fcsqlrel211111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLNNNH303_26_TR -target #PSQLNNNH303_26_TRF -consistgrp SQLGRPFC -name fcsqlrel2111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLNNNH303_31_TR -target #PSQLNNNH303_31_TRF -consistgrp SQLGRPFC -name fcsqlrel21111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLNNNH303_40_TR -target #PSQLNNNH303_40_TRF -consistgrp SQLGRPFC -name fcsqlrel211111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLNNNH002_09_TR -target #PSQLNNNH002_09_TRF -consistgrp SQLGRPFC -name fcsqlrel2111111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLCNNH001_02_TR -target #PSQLCNNH001_02_TRF -consistgrp SQLGRPFC -name fcsqlrel21111111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLNBNH206_07_TR -target #PSQLNBNH206_07_TRF -consistgrp SQLGRPFC -name fcsqlrel211111111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLNCNH204_04_TR -target #PSQLNCNH204_04_TRF -consistgrp SQLGRPFC -name fcsqlrel2111111111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLCEH283_C08_T -target #PSQLCEH283_C08_TF -consistgrp SQLGRPFC -name fcsqlrel21111111111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLCEH283_C25_T -target #PSQLCEH283_C25_TF -consistgrp SQLGRPFC -name fcsqlrel211111111111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLCEH283_C26_T -target #PSQLCEH283_C26_TF -consistgrp SQLGRPFC -name fcsqlrel2111111111111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLCEH283_C31_T -target #PSQLCEH283_C31_TF -consistgrp SQLGRPFC -name fcsqlrel21111111111111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLCEH283_C47_T -target #PSQLCEH283_C47_TF -consistgrp SQLGRPFC -name fcsqlrel211111111111111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLCEH285_20_T -target #PSQLCEH285_20_TF -consistgrp SQLGRPFC -name fcsqlrel2111111111111111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLCEH285_08_T -target #PSQLCEH285_08_TF -consistgrp SQLGRPFC -name fcsqlrel21111111111111111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLCEH286_17_T -target #PSQLCEH286_17_TF -consistgrp SQLGRPFC -name fcsqlrel211111111111111111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source #PSQLCEH286_08_T -target #PSQLCEH286_08_TF -consistgrp SQLGRPFC -name fcsqlrel2111111111111111111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source PSQLCHEH253_C19_T -target PSQLCHEH253_C19_TF -consistgrp SQLGRPFC -name fcsqlrel21111111111111111111111111111111 -copyrate 100 -cleanrate 100
plink DC2SVC01 -l admin mkfcmap -source PSQLCHEH253_C12_T -target PSQLCHEH253_C12_TF -consistgrp SQLGRPFC -name fcsqlrel211111111111111111111111111111111 -copyrate 100 -cleanrate 100



LSVDISK OUTPUT:
id:name:IO_group_id:IO_group_name:status:mdisk_grp_id:mdisk_grp_name:capacity:type:FC_id:FC_name:RC_id:RC_name:vdisk_UID:fc_map_count:copy_count:fast_write_state:se_copy_count:RC_change
0:PARCNNNH003_11:0:CAEC01IOG00:online:13:T04G02FST08FSS:429496729600:striped:::::6005076801850097A0000000000003E3:0:1:empty:0:no
1:PDATNNH022_05SE:0:CAEC01IOG00:online:22:T03G14AMS01:644245094400:striped:::::6005076801850097A0000000000007EE:0:1:not_empty:1:no
2:PARCNNNH004_09:1:CAEC01IOG01:online:20:T04G01FST07FSS:429496729600:striped:::::6005076801850097A0000000000003E4:0:1:empty:0:no
3:PSQLNNH230_08:0:CAEC01IOG00:online:31:T01G01DS8800SS:5368709120:striped:::::6005076801850097A0000000000007F2:0:1:empty:0:no
4:CMS01_02:0:CAEC01IOG00:online:22:T03G14AMS01:42949672960:striped:::::6005076801850097A0000000000005E9:0:1:not_empty:0:no
5:KVS03_01:0:CAEC01IOG00:online:20:T04G01FST07FSS:429496729600:striped:::::6005076801850097A000000000000021:0:1:empty:0:no
6:CMS02_02:1:CAEC01IOG01:online:12:T03G15AMS01:42949672960:striped:::::6005076801850097A0000000000005EA:0:1:not_empty:0:no
7:PARCNNNH006_07:1:CAEC01IOG01:online:8:T04G16AMS01:429496729600:striped:::::6005076801850097A000000000000708:0:1:empty:0:no
8:PARCNNNH003_27:1:CAEC01IOG01:online:8:T04G16AMS01:429496729600:striped:::::6005076801850097A0000000000005EB:0:1:empty:0:no
9:KVS02_05:1:CAEC01IOG01:online:20:T04G01FST07FSS:429496729600:striped:::::6005076801850097A000000000000022:0:1:empty:0:no
10:PARCNNNH004_19:0:CAEC01IOG00:online:8:T04G16AMS01:429496729600:striped:::::6005076801850097A000000000000525:0:1:empty:0:no
11:PARCNNNH003_21:1:CAEC01IOG01:online:20:T04G01FST07FSS:429496729600:striped:::::6005076801850097A000000000000526:0:1:empty:0:no
12:KVS04_07:1:CAEC01IOG01:online:20:T04G01FST07FSS:429496729600:striped:::::6005076801850097A000000000000020:0:1:not_empty:0:no
13:PSQLNNH227_01:0:CAEC01IOG00:online:31:T01G01DS8800SS:5368709120:striped:::::6005076801850097A000000000000627:0:1:empty:0:no
14:AAPPNNH235_01:0:CAEC01IOG00:online:22:T03G14AMS01:85899345920:striped:::::6005076801850097A0000000000006EC:0:1:empty:0:no
15:PSQLNNH230_09:1:CAEC01IOG01:online:31:T01G01DS8800SS:161061273600:striped:::::6005076801850097A0000000000007F3:0:1:not_empty:0:no
16:PSQLNNH230_10:0:CAEC01IOG00:online:31:T01G01DS8800SS:161061273600:striped:::::6005076801850097A0000000000007F4:0:1:not_empty:0:no
17:PDATNNH022_01:0:CAEC01IOG00:online:22:T03G14AMS01:644245094400:striped:::::6005076801850097A0000000000005B3:0:1:not_empty:0:no
18:PSQLNNNH303_27:0:CAEC01IOG00:online:31:T01G01DS8800SS:188978561024:striped:::::6005076801850097A0000000000004C2:0:1:not_empty:0:no
19:PARCNNNH007_06:1:CAEC01IOG01:online:8:T04G16AMS01:429496729600:striped:::::6005076801850097A000000000000709:0:1:empty:0:no
20:PSQLNANH211_02:1:CAEC01IOG01:online:31:T01G01DS8800SS:322122547200:striped:::::6005076801850097A00000000000032A:0:1:empty:0:no
.
.
.
