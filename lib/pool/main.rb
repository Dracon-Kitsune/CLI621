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
      Pool.init(@config,@pathes)
      if !File.exists?(@pathes["tasks"]) then
        File.open(@pathes["tasks"],"w"){|f|f.print "{}"}
      end
      Readline.completion_proc = proc do |s|
        @tags.map{|t|t["name"]}.grep(/^#{s}/)
      end
      Readline.completer_word_break_characters  = " "
      Readline.completion_append_character      = " "
      @prompt = "e621.net/pool> ".bold(@color)
    end
    # Run module specific updates, if there are any.
    def mod_update
    end

    def list(buf)
      content = [
        " Name".pad(59),
        "Posts",
        "Public "
      ]
      page,body = 1,[""]
      until body == Array.new do
        request = "query=#{buf.join(" ")}&page=#{page}"
        draw_box(content,page == 1 ? true : false) do
          body = @http.post("/pool/index.json",request).body.parse if page == 1
          body.each do |pool|
            pool = Pool.new(pool)
            puts "| #{pool.name.pad(58)} | #{pool.post_count.pad(5," ")} | #{pool.public ? "Yes   ".bold("green") : "No    ".bold("yellow")} |"
          end
        end
        if body != Array.new then
          page += 1
          fetch_thread = Thread.new do 
            body = @http.post("/pool/index.json",request).body.parse
          end
          print "Loading next page? [Y/n]"
          input = $stdin.gets.to_s.chomp
          fetch_thread.join
          body = Array.new if !(input.match(/^y/) || input == String.new)
        end
      end
    end

    def download(buf)
    end

    def update(buf)
    end

    def create(buf)
    end

    def destroy(buf)
    end

    def add(buf)
    end
    # Remove a task from the queue.
    def remove(buf)
    end

    # Print out helpful information. X3
    def help
      puts ["This is a list of all commands:",
        "list SEARCHPATTERN [Always the whole pattern is searched for.]",
        "download ID1 ID2 ID3 ...",
        "update ID1 ID2 ID3 ...",
        "create",
        "destroy ID1 ID2 ID3 ...",
        "add ID1 ID2 ID3 ...",
        "remove ID1 ID2 ID3 ...",
        "IDs for add and remove are actual pool IDs. Post IDs get asked in a second",
        "step, to perform adding or removing posts to/from pools."
      ]
    end
  end
end
