require 'rubygems'
gem 'camping'
require 'camping'

Camping.goes :Demo

module Demo::Controllers
  class Index < R '/'
    def get
      @message = "Hello, World!"
      render :index
    end
  end
  class Snoop < R '/snoop'
    def get
      @snoop = {}
      @snoop[:env] = env
      @snoop[:load_path] = $LOAD_PATH
      render :snoop
    end
  end
end

module Demo::Views
  def layout
    html do
      body do
        self << yield
      end
    end
  end

  def index
    h1 "Index"
    p "Camping says: #{@message}"
  end

  def dl_hash(hash)
    dl {
      hash.keys.each do |k|
        dt { text(k.to_s.humanize + "&nbsp;"); tt {k.to_s}}
        dd {
          if Hash === hash[k]
            dl_hash(hash[k])
          elsif Array === hash[k]
            ul { hash[k].each {|v| li { v }} }
          else
            text("  " + hash[k] + "\n")
          end
        }
      end
    }
  end

  def snoop
    h1 "Snoop"
    div dl_hash(@snoop)
  end
end
