cd $KARAFKA_HOME

if [ -e "./tmp/pids/karafka_server" ];then 
   cat ./tmp/pids/karafka_server|while read LINE 
   do
      if [ -n $LINE ];then
         echo $LINE
         kill -15 $LINE
         sleep 1
      fi
   done
fi 

if [ -e "./tmp/pids/karafka_server" ];then 
   rm ./tmp/pids/karafka_server
fi 

if [ -e "./tmp/pids/karafka" ];then 
   rm ./tmp/pids/karafka
fi