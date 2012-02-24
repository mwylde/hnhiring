require 'nokogiri'
require 'open-uri'
require 'json'
require 'redis'

SPACER = "http://ycombinator.com/images/s.gif"

def handle_time id, s
  redis = Redis.new
  if t = redis.get("hnhiring:comments:#{id}")
    Time.at(t)
  else
    _, n, unit = s.match(/(\d+) (seconds|minutes|hours|days) ago/)
    multiple = {"seconds" => 1, "minutes" => 60, "hours" => 60*60, "days" => 60*60*24}
    time = Time.now - n.to_i * multiple(unit)
    redis.set("hnhiring:comments:#{id}", time.to_i)
    time
  end
end

def get_comments(id)
  html = open("http://news.ycombinator.com/item?id=#{id}")
  doc = Nokogiri::HTML(html.read)
  comment_nodes = doc.css(".comment")
  comment_nodes.map{|c|
    submitter, link = c.parent.css("a")
    begin
      cid = link.attr('href').match(/id=(\d+)/)[1],
      time_string = c.parent.css(".comhead").children[1].to_s
      time = handle_time cid, time_string
      {
        :id => cid,
        :level => c.parent.parent.css("img[src=\"#{SPACER}\"]").first.attr('width').to_i / 40,
        :html => c.to_s,
        :submitter => submitter.text,
        :url => "http://news.ycombinator.com/#{link.attr('href')}",
        :belongs_to => nil,
        :time => time
      }
    rescue
    end
  }.compact.reduce([]){|a, c|
    if c[:level] == 0
    elsif c[:level] > a[-1][:level]
      c[:belongs_to] = a[-1][:id]
    elsif c[:level] == a[-1][:level]
      c[:belongs_to] = a[-1][:belongs_to]
    else
      c[:belongs_to] = a.select{|x| x[:level] == c[:level]-1}[-1][:id]
    end
    a << c
  }.reduce({}){|h, c|
    h[c[:id]] = c
    h
  }
end

def get_threads
  html = open('http://news.ycombinator.com/submitted?id=whoishiring')
  doc = Nokogiri::HTML(html.read)
  doc.css(".title a").map{|x| [x.text, x.attr("href").match(/id=(\d+)/)[1]]}.map{|t|
    date = t[0].match(/\((\w+) (\d+)\)/)
    if date
      date_str = "#{date[1][0..2]} #{date[2]} &mdash; "
      if t[0].match("Seeking freelancer")
        [date_str + "freelancers", t[1]]
      elsif t[0].match("Who is Hiring")
        [date_str + "fulltime", t[1]]
      end
    end
  }.compact
end

def load_data
  threads = get_threads
  comments_by_thread = {}
  threads.each{|t|
    begin
      comments_by_thread[t[1]] = get_comments(t[1])
      sleep 1 # try not to annoy PG
      puts "Loaded #{t[0]}"
    rescue
      puts "Failed on #{t[0]}: #{$!}"
    end
  }
  comments = comments_by_thread
  [threads, comments]
end

if __FILE__ == $0
  threads, comments = load_data
  File.open(ARGV[0] + "/threads.json", "w+"){|f|
    f.write(JSON.dump(threads))
  }
  comments.each{|id, data|
    File.open(ARGV[0] + "/comments-#{id}.json", "w+"){|f|
      f.write(JSON.dump(data))
    }
  }
end
