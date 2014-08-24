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

require "net/http"
require "thread"
require "time"
require "logger"
begin
  require "io/console"
rescue LoadError
end
require "e621"
require "standard/string"
#require "standard/hash"
require "standard/http"
require "standard/int"
require "standard/time"
require "error"
require "api"
require "tag"
require "user"

module E621
  class Main
    attr_reader :log
    def initialize
      Thread.abort_on_exception = true # abort on any error
      @debug      = ARGV.include?("-v") ? true : false # debug mode enabled?
      E621.debug  = @debug
      @version    = "0.1.1"
      @name       = "CLI621"
      if ARGV.include?("-V") then
        puts "#@name v#@version"
        exit
      end
      @tool       = File.basename($0)
      @home       = File.expand_path("~/.e621/")
      @tmp        = @debug ? "/tmp/e621.debug" : "/tmp/e621" 
      @mt         = Mutex.new
      @cli        = CLI.new("#@home/history_#@tool")
      @http       = HTTP.new
      @api        = API.new(@tool)
      @paths     = {
        "tasks"     => "#@tmp/tasks.json",
        "config"    => "#@home/conf.json",
        "tags"      => "#@home/tags.json",
        "info"      => "#@home/info.log",
        "blacklist" => "#@home/blacklist.json",
        "pass"      => "#@home/passwd.json",
        "posts"     => "#@home/posts",
        "cache"     => "#@home/cache",
        "home"      => @home,
        "tmp"       => @tmp
      }
      init # run private init function
    end
    # Start most of the needed helper functions and set up last things.
    def init
      t = Time.measure do
        # first of all, create a temporary directory
        Dir.mkdir(@tmp) unless File.exist?(@tmp)
        read_config
        set_logger
        login
        run_updates
        mod_init
      end
      E621.log.debug("Startup time: #{t.round(3)} s")
      command_loop
    end
    # Check if important files need to be updated and update each in its own
    # thread if needed.
    def run_updates
      @threads = Array.new
      # Synchronize blacklist in cache with user blacklist on site for every 0
      # to x minutes. Value is randomly chosen, to reduce impact on site.
      @threads << Thread.new do
        loop do
          sleep(rand(60*5))
          $user.update
        end
      end
      mod_update
    end
    # Read and parse a configuration file. Raise an error if none is found.
    def read_config
      conf = File.expand_path(@paths["config"])
      if !File.exist?(conf) then
       raise ConfigError, "No config file found. Installation corrupted!"
      end
      File.open(@paths["config"]) do |f|
        begin
          c = f.read.parse # read and parse configuration
        rescue
          raise ConfigError, "Configuration file corrupted!"
        end
        @config = c
        @config["cache"] = @config["cache"].to_s.to_bool
        @config["auto_login"] = @config["auto_login"].to_s.to_bool
        @config["tag_trash_hold"] = @config["tag_trash_hold"].to_i
        @config["threads"] = @config["threads"].to_i
        @config["cache_size"] = @config["cache_size"].to_i
        dir = File.expand_path(@config["paths"][@tool])
        if !File.exist?(File.dirname(dir)) then
          # If parent directory does not exist, then abort and say so!
          $stderr.puts "Parent directory #{dir} does not exist!"
          abort
        end
        Dir.mkdir(dir) unless File.exist?(dir)
        Dir.chdir(dir) # change working path
        @tag_trash  = @config["tag_trash_hold"]
        # Tags with a post count lower than this get ignored.
        @color      = @config["prompt_color"] # Prompt color.
      end
    end
    # Set up logger functions. User information on STDERR should still be given.
    def set_logger
      @log = Logger.new(@paths["info"])
      @log.formatter = proc do |sev,dat,prog,msg|
        "#{Time.now.strftime("%b %e, %Y %I:%M:%S.%L %p")}: #{msg}#$/"
      end
      @log.level  = Logger::INFO
      @log.level  = Logger::DEBUG if @debug
      E621.log    = @log
    end
    # Use user credentials to log them in on two levels. API and site login are
    # used.
    def login
      name = API.login(@paths,@config["auto_login"])
      $user = User.new(name)
    end
    # Draw a neat box around our input. Function expects a block.
    def draw_box(content,header=true)
      # Our content is an array of strings.
      border = "+#{content.map{|c|"-"*c.gsub(/\e\[\d+(;\d+)?m/,"").length}.join("-+-")}+"
      if header then
        puts border
        puts  "|"+content.join(" | ")+"|"
      end
      #p border.length
      puts border
      yield
      puts border
    end
    # The main function of this program and UI.
    def command_loop
      prompt = "#{$user.name}@e621.net#@prompt> "
      while buff = Readline.readline(prompt.bold(@color), false) do
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
  end
end
