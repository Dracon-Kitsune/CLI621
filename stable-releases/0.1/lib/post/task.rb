=begin
  Copyright 2014 Maxine Red <maxine_red1@yahoo.com>

  This file is part of CLI621.

  CLI621 is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  CLI621 is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with CLI621.  If not, see <http://www.gnu.org/licenses/>.
=end

module E621
  class Task
    attr_accessor :updated,:queries
    attr_reader :name
    # commands update/download
    def initialize(name,queries,posts=Array.new)
      @name,@queries,@posts = name,queries,posts.map{|o|Post.new(o)}
      @http = E621.connect
      @mt = Mutex.new
    end
    # Update this task with a new set of posts. Already updated tasks get
    # ignored to speed things up.
    def update
      File.open(@@pathes["blacklist"]) do |f|
        @bad_tags = f.read.parse.join("|") # Prepare our set of unwanted tags.
      end
      @queries.each do |q|
        next if q["updated"]
        body,@page = [1],1
        @bad,@got,@double,@total = 0,0,0,0
        query,@query = q["query"].join("+"),q["query"].join(" ")
        threading("update") do # Our function to keep the user informed.
          while body != Array.new do
            # While there are posts, look for more.
            begin
              request = "limit=100&page=#@page&tags=#@query&#@login"
              body = @http.post("/post/index.json",request).body.parse
              # Fetch an answer and handle intern or extern errors.
              if body.is_a?(Hash) && !body["success"] then
                $stderr.puts "Your search for #{query.gsub("+"," ".bold)} failed: #{body["reason"].body("red")}."
                body = Array.new
              end
            rescue
              raise
              puts "Request #{query.gsub("+"," ")} on page #@page raised an error (#$!)"
              break
            end
            body.each do |post|
              # Work on every post that got fetched.
              @total += 1
              bad_tags = /(\s|^)(#@bad_tags)(\s|$)/ # Set up bad tags properly
              if !post["tags"].match(bad_tags) && !@posts.index{|o| o.id == post["id"]} then
                # If post is not tagged with a bad tag and not already in our
                # collection, its good!
                @posts << Post.new(post)
                @got += 1
              elsif @posts.index{|o| o.id == post["id"]} then
                # Double posts don't get added again.
                @double += 1
              elsif post["tags"].match(bad_tags) then
                # And bad posts don't get added at all!
                @bad += 1
              else # Don't do anything unexpected.
              end
            end
            @page += 1 if body != Array.new # And to the next page!
          end
          q["updated"] = true # Tell everyone that we're done with this.
          sleep 0.5 # Wait a little to let everything update
          puts
        end
      end
    end
    # Initialize configuration class wide, so not each instance needs it too.
    def self.init(config,pathes)
      @@config = config
      @@pathes = pathes
    end
    # Add a query to the queue.
    def add(query)
      @queries << query
    end
    # A custom to_json function.
    def to_json(a,b)
      posts = @posts.map{|o|o.to_json}
      {"name"=>@name,"queries"=>@queries,"posts"=>posts}.to_json
    end
    # Download everything we already stored.
    def download
      # First of all, create the named directory, to put stuff, and then go into
      # said directory.
      Dir.mkdir(@name) unless File.exist?(@name)
      Dir.chdir(@name)
      if @@config["cache"] then
        Dir.mkdir(@@pathes["cache"]) unless File.exist?(@@pathes["cache"])
        cache_files = Dir[@@pathes["cache"]+"/*"]
        cache_files.map!{|f|[f,File.size(f)]}
        cache_files.sort!{|f1,f2|f2[1]<=>f1[1]}
        # Sort cache files after file size.
      end
      @id,@date,@got,@total = 0,0,0,@posts.length
      mt = Mutex.new
      max_threads = @@config["threads"].to_i <= 10 ? @@config["threads"].to_i : 10
      threads = [Thread.new{}]*max_threads # Prefork threads.
      @posts.sort!{|k1,k2|k1.id<=>k2.id} # Sort posts by ID.
      threading("download") do
        @posts.each do |post|
          until i = threads.index{|t|t.status==false} do
            # If all threads are busy, sleep a little bit and then check again.
            sleep 0.001
          end
          threads[i] = Thread.new(post) do |tpost|
            # When a thread ended, start a new one with a new task.
            id,file_url = tpost.id,tpost.file_url # Save us some typing here.
            file = File.basename(file_url)
            if @@config["cache"] then # Do we cache files?
              c_file = @@pathes["cache"]+"/#{file}"
              if File.exist?(c_file) then
                # If we cache and a file exists, don't download a new one!
                File.open(c_file) do |f|
                  File.open("#{id.pad(7)}.#{file}","w") do |g|
                    g.print f.read
                  end
                end
              else
                # If none exists, download a new one and check if the cache size
                # doesn't get too big.
                body = download_post(file_url,id)
                File.open(c_file,"w"){|f|f.print body}
                @mt.synchronize do
                  cache_files << [c_file,body.length]
                  cache_files.sort!{|f1,f2|f2[1]<=>f1[1]}
                  file_size = 0
                  cache_files.each{|f|file_size+=f[1]}
                  while file_size >= @@config["cache_size"].to_i*2**20 do
                    d_file = cache_files.shift
                    File.unlink(d_file[0])
                    file_size -= d_file[1]
                  end
                end
              end
            else
              # If we don't cache, just get stuff straight from the source, all
              # the time.
              download_post(file_url,id)
            end
            mt.synchronize do
              @got += 1
              @id = id if @id < id
              @date = tpost.created_at if @date < tpost.created_at
              # Just update all stats with the newest data.
            end
          end
        end
        threads.each{|t|t.join} 
        sleep 0.5
        # Wait for all threads to finish and a little to let user information
        # update.
      end
      Dir.chdir("..") # Return to the main directory.
      puts
    end
    private
    # Function to download a post.
    def download_post(file_url,id)
      http = Net::HTTP.new(file_url.match(%r[(?<=//).+?(?=/)]).to_s,443)
      http.use_ssl = true
      length, body = 2,""
      until length <= body.length do
        head,body = http.get(file_url.sub(/.+?net/,""))
        length = head["content-length"].to_i
      end
      file = File.basename(file_url)
      File.open("#{id.pad(7)}.#{file}","w"){|f|f.print body}
      return body
    end
    # User information for several threads.
    def threading(t)
      task = case t
             when "update" then "<name:8:normal> | <query:15:normal> | <page:4:purple> | <bad:7:red> | <got:7:green> | <double:7:blue> | <total:7:bold>|"
             when "download" then "<name:12:normal> | <got:7:normal>/<total:7:bold> | <id:7:green> | <date:30:yellow>|"
             end
      thread = Thread.new do
        loop do
          ["|","/","-","\\"].each do |s|
            text = task.gsub(/<.+?>/) do |m|
              m.gsub!(/<|>/,"")
              n,c,b = m.split(":")
              if n != "date" then
                t = instance_variable_get("@#{n}".to_sym).to_s.pad(c.to_i)
              else
                t = Time.at(@date).strftime("%b %e, %Y %I:%M %p").pad(c.to_i)
              end
              t = t.bold(b) if b != "normal"
              t
            end
            print "[#{s}] | #{text}\r"
            sleep 0.25
          end
        end
      end
      yield
      thread.exit
    end
  end
end
