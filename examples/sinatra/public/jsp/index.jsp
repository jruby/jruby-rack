<html>
  <head><title>Sinatra forwards to JSP</title></head>
  <link rel="stylesheet" href="http://yui.yahooapis.com/2.8.0r4/build/reset/reset-min.css" type="text/css" media="screen, projection">
  <link rel="stylesheet" href="style.css" type="text/css" media="screen, projection">
  <link rel="shortcut icon" href="favicon.ico">
  <body>
    <div id="content">
      <div class="inside_jsp">
        This page has been generated from a JSP.  The servlet request attribute is <%= request.getAttribute("message") %>
      </div>  
    </div>
  </body>
</html>
