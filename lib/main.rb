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
require "standard/hash"
require "standard/int"
require "tag"

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
      @home       = File.expand_path("~/.e621/")
      @tmp        = @debug ? "/tmp/e621.debug" : "/tmp/e621" 
      @mt         = Mutex.new
      @cli        = CLI.new(@home+"/history")
      @http       = E621.connect
      @pathes     = {
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
      # first of all, create a temporary directory
      Dir.mkdir(@tmp) unless File.exist?(@tmp)
      read_config
      set_logger
      login
      run_updates
      mod_init
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
      mod_update
    end
    # Read and parse a configuration file. Raise an error if none is found.
    def read_config
      conf = File.expand_path(@pathes["config"])
      if !File.exist?(conf) then
       raise ConfigError, "No config file found. Installation corrupted!"
      end
      File.open(@pathes["config"]) do |f|
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
        dir = [""]
        File.expand_path(c["picture_path"]).split("/").each do |d|
          # Create our working directory first!
          dir << d
          Dir.mkdir(dir.join("/")) unless File.exist?(dir.join("/"))
          # If our directory does not exist, make it.
        end
        Dir.chdir(File.expand_path(c["picture_path"])) # change working path
        @tag_trash  = @config["tag_trash_hold"]
        # Tags with a post count lower than this get ignored.
        @color      = @config["prompt_color"] # Prompt color.
      end
    end
    # Set up logger functions. User information on STDERR should still be given.
    def set_logger
      @log = Logger.new(@pathes["info"])
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
      #Load all user credentials into one variable.
      File.open(@pathes["pass"]){|f|@passwd=f.read.parse}
      @login,@cookie = @passwd["login"],@passwd["cookie"]
      name,pass = String.new, String.new
      # Perform a re-login if the last time is older than x days.
      if (Time.now.to_i-@passwd["last_login"].to_i) > 60*60*24*3 then
        if @config["auto_login"] then
          @http.get("/user/logout",{"cookie"=>@cookie.to_s}) if @cookie
          if @passwd["name"] != "" && @passwd["pass"] != "" then
            name,pass = @passwd["name"],@passwd["pass"]
          else
            puts "No user data found. Please provide user data."
            name,pass = get_credentials
            @passwd["name"],@passwd["pass"] = name,pass
            # Store that data for later use.
          end
        else
          name,pass = get_credentials
        end
        request = "name=#{name}&password=#{pass}"
        body = @http.post("/user/login.json",request).body.parse
        if body.has_key?("success") && (!body["success"] || body["success"] = "failed") then
          raise AuthentificationError, "Username or password wrong!"
        else
          @login = "login=#{body["name"]}&password_hash=#{body["password_hash"]}"
          @passwd["login"] = @login # Save login string for later use.
        end
        request = "url=&user%5Bname%5D=#{@passwd["name"]}&user%5Bpassword%5D=#{@passwd["pass"]}&user%5Broaming%5D=1"
        # Log in user on site, after logging into API is done.
        head,body = @http.post("/user/authenticate",request)
        @cookie = head["set-cookie"]
        @passwd["cookie"] = @cookie 
        @passwd["last_login"] = Time.now.to_i
        # Write everything back!
        File.open(@pathes["pass"],"w"){|f|f.print @passwd.to_json}
      end
    end
    # Draw a neat box around our input. Function expects a block.
    def draw_box(content,header=true)
      # Our content is an array of strings.
      border = "+#{content.map{|c|"-"*c.gsub(/\e\[\d+(;\d+)?m/,"").length}.join("-+-")}+"
      if header then
        puts border
        puts  "|"+content.join(" | ")+"|"
      end
      puts border
      yield
      puts border
    end
    # If there is no data saved for login, ask the user. They must know!
    def get_credentials
      print "Username: "
      name = $stdin.gets.chomp
      if $stdin.respond_to?(:noecho) then
        print "Password: "
        pass = $stdin.noecho(&:gets).chomp
      else
        pass = `read -s -p "Password: " pass; echo $pass`.chomp
      end
      return [name,pass]
    end
    # The main function of this program and UI.
    def command_loop
      while buff = Readline.readline(@prompt, false) do
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
