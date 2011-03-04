This directory contains output from JRuby-Rack's capture feature for
several different servers.

To generate one for your environment, build the sinatra example
application (../sinatra) with Warbler, deploy it into your server,
then load the application in a browser and navigate to the 'env'
action.

If you built the example application on the same machine where you
deployed it, a copy of the capture will be written into this
directory.

### Scripts

- `server.sh` is a wrapper script for launching a server with a
  uniform command line. Look in the script for a list of supported
  servers. (The paths to the servers are currently hardcoded for
  Nick's development machine but you can either set environment
  variables or customize it for your use.)

    server.sh tc6 start
    server.sh tc6 stop
    server.sh jetty6 start
    server.sh jetty6 stop

- `test.sh` makes use of `server.sh` to run a simple list of tests
  using `curl` to ensure that JRuby-Rack is deploying successfully on
  all the supported servers.

### Notes

- Jetty 7 notes: Apps fail to load unless the following is set in
  etc/jetty-deploy.xml:
     <Set name="extractWars">true</Set>
   

