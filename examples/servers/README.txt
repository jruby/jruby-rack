This directory contains output from JRuby-Rack's capture feature for
several different servers.

To generate one for your environment, build the sinatra example
application (../sinatra) with Warbler, deploy it into your server,
then load the application in a browser and navigate to the 'env'
action.

If you built the example application on the same machine where you
deployed it, a copy of the capture will be written into this
directory.

### Notes

- Jetty 7 notes: Apps fail to load unless the following is set in
  etc/jetty-deploy.xml:
     <Set name="extractWars">true</Set>
   

