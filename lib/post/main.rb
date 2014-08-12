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
  class Main
    private
    # Start most of the needed helper functions and set up last things.
    def init
      # first of all, create a temporary directory
      Dir.mkdir(@tmp) unless File.exist?(@tmp)
      read_config
      File.open(@pathes["tags"],"w"){|f|f.print "[]"} unless File.exist?(@pathes["tags"])
      # create a tag file if none exists
      File.open(@pathes["tags"]) do |f|
        @tags = f.read.parse # read all tags inside of the json string
        $tags = @tags
      end
      set_logger
      login
      run_updates
      Task.init(@config,@pathes)
      Post.init(@config,@pathes)
      command_loop
    end
    # Check if important files need to be updated and update each in its own
    # thread if needed.
    def run_updates
      @threads = Array.new
      diff = Time.now-File.mtime(@pathes["tags"])
      if diff.to_i >= 60*60*24*7 then # Just update if cache is older than a week.
        @threads << Thread.new do
          http = E621.connect
          # Report when task starts.
          @log.info "Tags update: start"
          tags,body,page = Array.new,["1"],1
          while body != Array.new do # If no tags are read, end loop.
            request = "limit=100&page=#{page}&order=count&#@login"
            @mt.synchronize do
              body = http.post("/tag/index.json",request).body.parse
            end
            tags += body.reject{|x|x["name"].match(/[^a-z,_,\-,0-9,\?,\!,\(,\),\[,\],\{,\},\\,\/]/)||x["count"].to_i<=@tag_trash}
            body = Array.new if body.last["count"] < @tag_trash
            @log.info "Tags update: got page ##{page}" if page % 50 == 0
            page += 1
          end
          File.open(@pathes["tags"],"w") do |f|
            f.print tags.to_json
          end
          # Report when task ended.
          @log.info "Tags update: end"
        end
      end
      # Synchronize blacklist in cache with user blacklist on site for every 0
      # to x minutes. Value is randomly chosen, to reduce impact on site.
      @threads << Thread.new do
        loop do
          http = E621.connect
          @mt.synchronize do
            head,body = http.get("/post",{"cookie"=>@cookie.to_s})
            @cookie = head["set-cookie"]
            @cookie =~ /(?<=blacklisted_tags=).+?(?=;)/
            blacklist = $~.to_s
            if blacklist != String.new then
              File.open(@pathes["blacklist"],"w") do |f|
                f.print blacklist.split("&").to_json
              end
            end
            @passwd["cookie"] = @cookie 
            File.open(@pathes["pass"],"w"){|f|f.print @passwd.to_json}
          end
          sleep(rand(60*5))
        end
      end
    end
    # The main function of this program and UI.
    def command_loop
      if !File.exists?(@pathes["tasks"]) then
        File.open(@pathes["tasks"],"w"){|f|f.print "{}"}
      end
      Readline.completion_proc = proc do |s|
        @tags.map{|t|t["name"]}.grep(/^#{s}/)
      end
      Readline.completer_word_break_characters  = " "
      Readline.completion_append_character      = " "
      while buff = Readline.readline("e621.net/post> ".bold(@color), false) do
        if !(buff == String.new || buff == Readline::HISTORY.to_a.last) then
          Readline::HISTORY << buff
          @cli.history.puts buff
        end
        cmds = buff.split(";")
        while buf = cmds.shift do
          buf = buf.split(/\s+/)
          __send__(buf.shift.downcase.to_sym,buf)
        end
      end
    end
    # This is a general purpose function to work on tasks. This function needs
    # a block to work properly.
    def work_task
      f = File.open(@pathes["tasks"],"a+")
      @tasks = f.read.parse.map{|t|Task.new(t["name"],t["queries"],t["posts"])}
      if !f.flock(File::LOCK_NB|File::LOCK_EX) then
        $stderr.puts "Another process is working on tasks" 
        @log.info "Another process is working on tasks" 
      end
      yield
      f.truncate(0)
      f.print @tasks.to_json
      f.flock(File::LOCK_UN)
      f.close
    end
    # Add a task to the queue.
    def add(buffer)
      if !buffer.first.match(/^name/) then
        $stderr.puts "No name for task given."
        @log.error "No name for task given."
        return
      end
      # If the first argument is a name, continue.
      name = buffer.shift.sub(/^name:/,"")
      # If a task of the same name already exists, just add this one to that.
      # If none exists, create a whole new task.
      work_task do
        if id = @tasks.index{|t|t.name==name} then
          @tasks[id].add({"query"=>buffer,"updated"=>false})
        else
          @tasks << Task.new(name,[{"query"=>buffer,"updated"=>false}])
        end
      end
    end
    # Remove a task from the queue.
    def remove(buf)
      work_task do
        name = buf.grep(/^name:/).first.sub(/^name:/,"")
        tasks.reject{|t|t.name==name}
      end
    end

    def show(buf)
      buf.each{|id|Post.new(id.to_i).show}
    end

    def voteup(buf)
      buf.each{|id|Post.new(id.to_i).vote(1)}
    end

    def votedown(buf)
      buf.each{|id|Post.new(id.to_i).vote(-1)}
    end

    def fav(buf)
      buf.each{|id|Post.new(id.to_i).fav}
    end

    def unfav(buf)
      buf.each{|id|Post.new(id.to_i).fav(false)}
    end

    def update(buf)
      minus = ["-"*3,"-"*8,"-"*15,"-"*4,"-"*7,"-"*7,"-"*7,"-"*7].join("-+-")+"+"
      puts minus
      puts ["   ",
        "Task".pad(8),
        "Query".pad(15),
        "page".bold("purple"),
        "bad".pad(7).bold("red"),
        "good".pad(7).bold("green"),
        "double".pad(7).bold("blue"),
        "total".pad(7).bold
      ].join(" | ")+"|"
      puts minus
      work_task do
        @tasks.each{|t|t.update}
      end
      puts minus
    end

    def download(buf)
      #Task | got/max | date
      minus = ["---","-"*12,"-"*15,"-"*7,"-"*30].join("-+-")+"+"
      puts minus
      puts ["   ","Task".pad(12),"Posts".pad(15),"ID".pad(7),"Date".pad(30)].join(" | ")+"|"
      puts minus
      work_task do
        while task = @tasks.shift do
          task.download
        end
      end
      puts minus
    end
    # Print out helpful information. X3
    def help
      puts ["This is a list of all commands:",
        "add name:NAME TAG1 [TAG2 TAG3 ...]",
        "remove name:NAME",
        "show ID1 [ID2 ID3 ...]",
        "voteup ID1 [ID2 ID3 ...]",
        "votedown ID1 [ID2 ID3 ...]",
        "fav ID1 [ID2 ID3 ...]",
        "unfav ID1 [ID2 ID3 ...]",
        "update",
        "download"]
    end
    # A error function, that parses all kinds of Ruby or e621.net generated
    # errors. All it takes is a post ID.
    def error(id)
      if $!.to_s.length < 128 then
        @log.error "Post ##{id} caused an error: #$!"
      else
        $!.to_s =~ /<pre>.+<\/pre>/
        err = $~.to_s
        err = err.gsub(/<pre>|<\/pre>/,"").gsub("&gt;",">").gsub("&lt;","<").gsub("&#39","'")
        @log.error "Post ##{id} caused a remote error: #{err}.#$/Aborting!"
        abort
      end
    end
  end
end
