#!/bin/bash

unset JAVA_OPTS

if [ -z "$GFV3" ]; then
    GFV3=~/Projects/java/glassfishv3/glassfish
fi

if [ -z "$JETTY6" ]; then
    JETTY6=~/Projects/java/jetty-6.1.25
fi

if [ -z "$JETTY7" ]; then
    JETTY7=~/Projects/java/jetty-7.1.6.v20100715
fi

if [ -z "$TC6" ]; then
    TC6=~/Projects/java/apache-tomcat-6.0.14
fi

if [ -z "$TC7" ]; then
    TC7=~/Projects/java/apache-tomcat-7.0.2
fi

if [ -z "$JBOSS5" ]; then
    JBOSS5=~/Projects/java/jboss-5.1.0.GA
fi

if [ -z "$JBOSS6" ]; then
    JBOSS6=~/Projects/java/jboss-6.0.0.Final
fi

if [ -z "$RESIN" ]; then
    RESIN=~/Projects/java/resin-4.0.13
fi

start_cmd=
stop_cmd=
deploy_dir=

server=$1
if [ -z "$server" ]; then
    echo 'usage: server.sh <(start|stop)> <server> [warfile]'
fi

start_stop=$2
case $start_stop in
    start|stop|redeploy)
	;;
    *)
	echo "Specify 'start' or 'stop' for the first argument."
	exit 1
	;;
esac

case $server in
    tc6|tomcat6)
	start_cmd="$TC6/bin/catalina.sh start"
	stop_cmd="$TC6/bin/catalina.sh stop"
	deploy_dir=$TC6/webapps
	;;
    tc7|tomcat7)
	start_cmd="$TC7/bin/catalina.sh start"
	stop_cmd="$TC7/bin/catalina.sh stop"
	deploy_dir=$TC7/webapps
	;;
    jetty6)
	start_cmd="$JETTY6/bin/jetty.sh start"
	stop_cmd="$JETTY6/bin/jetty.sh stop"
	deploy_dir=$JETTY6/webapps
	;;
    jetty7)
	start_cmd="$JETTY7/bin/jetty.sh start"
	stop_cmd="$JETTY7/bin/jetty.sh stop"
	deploy_dir=$JETTY7/webapps
	;;
    glassfish|gf|gfv3)
	start_cmd="$GFV3/bin/asadmin start-domain"
	stop_cmd="$GFV3/bin/asadmin stop-domain"
	deploy_dir=$GFV3/domains/domain1/autodeploy
	;;
    jboss5)
	start_cmd="$JBOSS5/bin/run.sh &"
	stop_cmd="$JBOSS5/bin/shutdown.sh -S"
	deploy_dir=$JBOSS5/server/default/deploy
	;;
    jboss6)
	start_cmd="$JBOSS6/bin/run.sh &"
	stop_cmd="$JBOSS6/bin/shutdown.sh -S"
	deploy_dir=$JBOSS6/server/default/deploy
	;;
    resin)
	start_cmd="$RESIN/bin/resin.sh start"
	stop_cmd="$RESIN/bin/resin.sh stop"
	deploy_dir=$RESIN/webapps
	;;
    *)
	echo Unknown server $server.
	echo Servers are: tc6 tc7 jetty6 jetty7 glassfish jboss5 jboss6 resin
	exit 1
esac

war=${3-../sinatra/sinatra.war}
if [ ! -f $war ]; then
    echo Please build $war first with Warbler.
    exit 1
fi

war_base=$(basename $war .war)

case $start_stop in
    start)
	rm -rf $deploy_dir/${war_base}*
	echo "Copying $war to $deploy_dir"
	cp $war $deploy_dir
	eval "$start_cmd"
	;;
    stop)
	rm -rf $deploy_dir/${war_base}*
	eval "$stop_cmd"
	;;
    redeploy)
	rm -rf $deploy_dir/${war_base}*
	echo "Copying $war to $deploy_dir"
	cp $war $deploy_dir
	;;
esac
