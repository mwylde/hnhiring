require 'sinatra'
require 'nokogiri'
require 'open-uri'
require 'json'

SPACER = "http://ycombinator.com/images/s.gif"

def get_comments(id)
  doc = Nokogiri::HTML(open("http://news.ycombinator.com/item?id=#{id}"))
  comment_nodes = doc.css(".comment")
  comment_nodes.map{|c|
    submitter, link = c.parent.css("a")
    {
      :id => link.attr('href').match(/id=(\d+)/)[1],
      :level => c.parent.parent.css("img[src=\"#{SPACER}\"]").first.attr('width').to_i / 40,
      :html => c.to_s,
      :submitter => submitter.text,
      :url => "http://news.ycombinator.com/#{link.attr('href')}",
      :belongs_to => nil
    }
  }.reduce([]){|a, c|
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
  doc = Nokogiri::HTML(open('http://news.ycombinator.com/submitted?id=whoishiring'))
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

configure do
  set :threads, get_threads
  comments_by_thread = {}
  settings.threads.each{|t|
    begin
      comments_by_thread[t[1]] = get_comments(t[1])
      sleep 1 # try not to annoy PG
      puts "Loaded #{t[0]}"
    rescue
      puts "Failed on #{t[0]}"
    end
  }
  set :comments, comments_by_thread
end

get '/comments/:id' do
  JSON.dump(settings.comments[params[:id]])
end

get '/threads' do
  JSON.dump(settings.threads)
end
