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
    # Do module specific tasks here.
    def mod_init
      File.open(@paths["tags"],"w"){|f|f.print "[]"} unless File.exist?(@paths["tags"])
      # create a tag file if none exists
      File.open(@paths["tags"]) do |f|
        @tags = f.read.parse # read all tags inside of the json string
        $tags = @tags
      end
      Task.init(@config,@paths)
      Post.init(@config,@paths)
      if !File.exists?(@paths["tasks"]) then
        File.open(@paths["tasks"],"w"){|f|f.print "{}"}
      end
      Readline.completion_proc = proc do |s|
        @tags.map{|t|t["name"]}.grep(/^#{s}/)
      end
      Readline.completer_word_break_characters  = " "
      Readline.completion_append_character      = " "
      @prompt = "e621.net/post"
    end
    # Run module specific updates, if there are any.
    def mod_update
      diff = Time.now-File.mtime(@paths["tags"])
      diff = 0 if File.size(@paths["tags"]) <= 2 # Update if tags are empty!
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
          File.open(@paths["tags"],"w") do |f|
            f.print tags.to_json
          end
          # Report when task ended.
          @log.info "Tags update: end"
        end
      end
    end
    # This is a general purpose function to work on tasks. This function needs
    # a block to work properly.
    def work_task
      f = File.open(@paths["tasks"],"a+")
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
      content = ["  ",
        "Task".pad(8),
        "Query".pad(15),
        "page".bold("purple"),
        "bad".pad(7).bold("red"),
        "good".pad(7).bold("green"),
        "double".pad(7).bold("blue"),
        "total".pad(7).bold
      ]
      draw_box(content) do
        work_task do
          @tasks.each{|t|t.update}
        end
      end
    end

    def download(buf)
      #Task | got/max | date
      content = ["  ","Task".pad(12),"Posts".pad(15),"ID".pad(7),"Date".pad(30)]
      draw_box(content) do
        work_task do
          while task = @tasks.shift do
            task.download
          end
        end
      end
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
  end
end
