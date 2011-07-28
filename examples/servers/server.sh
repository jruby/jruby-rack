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

if [ -z "$APPENGINE" ]; then
    APPENGINE=~/Projects/appengine/appengine-java-sdk-1.4.2
fi

usage() {
    echo 'usage: server.sh <server> <(start|stop)> [warfile]'
    echo Servers are: tc6 tc7 jetty6 jetty7 glassfish jboss5 jboss6 resin appengine
}

start_cmd=
debug_cmd=
stop_cmd=
deploy_dir=

server=$1
if [ -z "$server" ]; then
    usage
fi

start_stop=$2
case $start_stop in
    start|stop|redeploy|debug)
	;;
    *)
	echo "Specify 'start' or 'stop' for the second argument."
	exit 1
	;;
esac

case $server in
    tc6|tomcat6)
	start_cmd="$TC6/bin/catalina.sh start"
	debug_cmd="$TC6/bin/catalina.sh jpda start"
	stop_cmd="$TC6/bin/catalina.sh stop"
	deploy_dir=$TC6/webapps
	;;
    tc7|tomcat7)
	start_cmd="$TC7/bin/catalina.sh start"
	debug_cmd="$TC7/bin/catalina.sh jpda start"
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
	start_cmd="$GFV3/bin/asadmin start-domain && sleep 2"
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
    appengine|gae)
	start_cmd='cd $deploy_dir && mkdir $war_base && cd $war_base && jar xf ../$war_base.war && $APPENGINE/bin/dev_appserver.sh . &'
	stop_cmd='kill $(jps -ml | grep DevAppServer | awk "{ print \$1 }")'
	deploy_dir="$TMPDIR"
	;;
    winstone)
	start_cmd='java -jar $war --prefix=/$war_base &'
	stop_cmd='kill $(jps -ml | grep $war_base | awk "{ print \$1 }")'
	deploy_dir="$TMPDIR"
	;;
    *)
	echo Unknown server $server.
	usage
	exit 1
esac

war=${3-../sinatra/sinatra.war}
if [ ! -f $war ]; then
    echo Please build $war first with Warbler.
    exit 1
fi

war_base=$(basename $war .war)

case $start_stop in
    start|debug)
	rm -rf $deploy_dir/${war_base}*
	echo "Copying $war to $deploy_dir"
	cp $war $deploy_dir
	if [ $start_stop = debug -a "$debug_cmd" ]; then
	    eval "$debug_cmd"
	else
	    eval "$start_cmd"
	fi
	;;
    stop)
	eval "$stop_cmd"
	rm -rf $deploy_dir/${war_base}*
	;;
    redeploy)
	rm -rf $deploy_dir/${war_base}*
	echo "Copying $war to $deploy_dir"
	cp $war $deploy_dir
	;;
esac
