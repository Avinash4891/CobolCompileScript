echo "Starting Build"
#db2dclgn -d BOOKS -t db2admin.EMPLOYEE -l cobol -a replace -n EMP- -c -i
moduleType=''

cd $AGENT_WORKDIR/workspace/$JOB_NAME

rm -rf ./dbrm
rm -rf ./precomp
rm -rf ./load
mkdir load

count=`ls -1 *.sqb 2>/dev/null | wc -l`

if [ $count != 0 ]
then 
echo "DB2 Connection required | Attempting connection to $DB2SERVERIP:$DB2SERVERPORT"
#db2 UNCATALOG NODE tcpnode 
#db2 UNCATALOG DB TESTDB 
db2 CATALOG TCPIP NODE tcpnode REMOTE $DB2SERVERIP SERVER $DB2SERVERPORT REMOTE_INSTANCE DB2INST1
db2 CATALOG DB $DBNAME AT NODE tcpnode AUTHENTICATION SERVER
db2 TERMINATE
db2 CONNECT TO $DBNAME USER $USER USING $PASSWORD;
mkdir ./dbrm
mkdir ./precomp

fi 

setModuleType () {

    count=`grep "PROCEDURE DIVISION" $file | awk '$1 !~ /[*]/' | awk '$3 == "USING"' | wc -l`
    if [ $count != 0 ]
    then
    moduleType='m'
    else
    moduleType='x'
    fi
}



for file in ./*; 
  do  

    filename=$(basename -- "$file") 

    extension="${filename##*.}" 

    filename="${filename%.*}"   
    

     echo "$filename"  ":"  "$extension"
     echo `grep "PROCEDURE DIVISION" $file | awk '$1 !~ /[*]/' | awk '$3 == "USING"' | wc -l`
     
      case "$extension" in
   		"sqb") #It is a cobol db2 program -> precompile, bind, and compile 
            db2 prep $file BINDFILE TARGET ANSI_COBOL ;
            mv ./"$filename".bnd ./dbrm
            mv ./"$filename".cbl ./precomp
            db2 bind ./dbrm/"$filename".bnd;

            setModuleType
            cobc -$moduleType -std=ibm -o ./load/"$filename" ./precomp/"$filename".cbl -fnot-reserved=TITLE -I"/opt/ibm/db2/V11.5/include/cobol_mf" -L"/opt/ibm/db2/V11.5/lib64" -ldb2     
   			
        ;;
   		"cbl") 
            setModuleType
        	cobc -$moduleType -std=ibm -o ./load/"$filename" ./$file
   		;;
   		"cob") 
        	setModuleType
        	cobc -$moduleType -std=ibm -o ./load/"$filename" ./$file
   		;;
	esac
    
done

#commit push
git add .
git commit -m "adding loads"

  #git config --global user.email $GIT_COMMITTER_EMAIL
  #git config --global user.name $GIT_COMMITTER_NAME
  

#git push origin master



echo "Build Successfull"
