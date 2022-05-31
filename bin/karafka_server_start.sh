count=$1

int=1

if [ -z $count ];then
   count=4
fi

cd $KARAFKA_HOME

source $rvm_path/scripts/rvm

rvm use ruby-2.6.3

rvm gemset use karafka

if [ -e "./tmp/pids/karafka_server" ];then
   echo "Karafka server already started. Please shutdown first."
   exit
fi 

while(( $int<= count ))
do
   echo $int
   let "int++"

   if [ -e "./tmp/pids/karafka" ];then 
      rm ./tmp/pids/karafka
   fi 
   
   bundle exec karafka s -d
   # sleep(5)
   while ( [ ! -e "./tmp/pids/karafka" ] )
   do
      sleep 1
      # echo "sleep 1"
   done
   cat ./tmp/pids/karafka >> ./tmp/pids/karafka_server
   echo '' >> ./tmp/pids/karafka_server

   # rm ./tmp/pids/karafka

   sleep 1
done
