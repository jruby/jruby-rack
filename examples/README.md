## JRuby-Rack Examples

This directory includes samples using JRuby-Rack to build Rack web applications for deployment
into Java app servers.

- All use [Warbler](https://github.com/jruby/warbler) to do so for easy of packaging.
- Require JRuby `9.4` and a compatible JVM (Java `8` -> `25`).

### Building/running

For deployment into a separate webserver:

1. ```bash
    bundle
    bundle exec warble war
    ```
2. Drop the war into a relevant Java app server running a compatible JVM version

As an executable jar within Jetty:

1. ```bash
    bundle
    bundle exec warble executable war
    ```
2. ```shell
    java -jar *.war
    ```

## Demo routes

| Example | Component              | Embedded Route                      | Deployed War Route                          |
|---------|------------------------|-------------------------------------|---------------------------------------------|
| Rails 7 | Status Page            | http://localhost:8080/up            | http://localhost:8080/rails7/up             |
| Rails 7 | Snoop Dump             | http://localhost:8080/snoop         | http://localhost:8080/rails7/snoop          |
| Rails 7 | Simple Form submission | http://localhost:8080/simple_form   | http://localhost:8080/rails7/simple_form    |
| Rails 7 | Body Posts             | http://localhost:8080/body          | http://localhost:8080/rails7/body           |
| Rails 7 | JSP (render)           | http://localhost:8080/jsp/          | http://localhost:8080/rails7/jsp/           |
| Rails 7 | JSP (forward to)       | http://localhost:8080/jsp-forward/  | http://localhost:8080/rails7/jsp-forward/   |
| Rails 7 | JSP (include)          | http://localhost:8080/jsp-include/  | http://localhost:8080/rails7/jsp-include/   |
| Sinatra | Demo Index             | http://localhost:8080/              | http://localhost:8080/sinatra               |
| Sinatra | Info                   | http://localhost:8080/info          | http://localhost:8080/sinatra/info          |
| Sinatra | Snoop Dump             | http://localhost:8080/env           | http://localhost:8080/sinatra/env           |
| Sinatra | JSP (render)           | http://localhost:8080/jsp/index.jsp | http://localhost:8080/sinatra/jsp/index.jsp |
| Sinatra | JSP (forward to)       | http://localhost:8080/jsp_forward   | http://localhost:8080/sinatra/jsp_forward   |
| Sinatra | JSP (include)          | http://localhost:8080/jsp_include   | http://localhost:8080/sinatra/jsp_include   |
| Sinatra | Streaming Demo         | http://localhost:8080/stream        | http://localhost:8080/sinatra/stream        |
| Camping | Demo Index             | http://localhost:8080/              | http://localhost:8080/camping               |
| Camping | Snoop Dump             | http://localhost:8080/snoop         | http://localhost:8080/camping/snoop         |

## Development

You can run the examples using local source for warbler or jruby-rack using env vars, e.g

```shell
export WARBLER_SRC=true JRUBY_RACK_SRC=true && bundle && bundle exec warble executable war && java -Dwarbler.debug=true -jar rails*.war
```

- Warbler can run directly from source
- jruby-rack needs to be built, since it does not define a gemspec
  - There are alternate ways to do this by replacing the jruby-rack jar within the warbled jar/war, however this is more
    complex and error-prone that using the gem and ensuring compatibility since warbler itself depends on the jruby-rack gem. 