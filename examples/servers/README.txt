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

- Handling of / => index.html seems to work differently depending on
  the server. It would be nice for JRuby-Rack to normalize them but I
  haven't figured out the proper magic yet.

    winstone	redirect to /index.html
    tomcat 6	dynamic dispatch to /
    tomcat 7	dynamic dispatch to /
    gf 3.1	dynamic dispatch to /
    jetty 6	shows index.html
    jetty 7	shows index.html
    resin 4	shows index.html
    jboss 5.1	dynamic dispatch to /
    jboss 6.0	dynamic dispatch to /

- Jetty 7 notes: Apps fail to load unless the following is set in etc/jetty-deploy.xml:
     <Set name="extractWars">true</Set>
   

