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
  class Post
    # commands show/fav/unfav/voteup/votedown
    attr_reader :id,:file_url,:created_at
    def initialize(post)
      File.open(@@paths["pass"]) do |f|
        @passwd = f.read.parse
        @login,@cookie = @passwd["login"],@passwd["cookie"]
      end
      file = "#{@@paths["posts"]}/#{"0"*(7-id.to_s.length)}#{id}.json"
      E621.log.debug("Post is given as a #{post.class} object and has the following content: #{post.inspect}.")
      if post.is_a?(Fixnum) then
        @id, @api = post, API.new
        post = @api.post("show",{"id"=>@id})
      elsif post.is_a?(Hash) then # If post argument is already a Hash object.
        @id = post["id"]
        code = 200
      end
      if code < 300 then
        @post = post
        post.each do |k,v|
          instance_variable_set("@#{k.gsub(/[-]/,"_")}",v)
        end
        @created_at = @created_at["s"].to_i if @created_at.is_a?(Hash)
      else
        errorcode(code)
      end
    end
    # Initialize configuration class wide, so not each instance needs it too.
    def self.init(config,paths)
      @@config,@@paths = config,paths
    end
    # Vote a post up or done. The argument "direction" indicates if it is an up
    # vote or down vote. Possible values are +1 or -1.
    def vote(direction)
      begin
        if direction.abs != 1 then
          raise ArgumentError, "Wrong parameter given. Parameter can only be +1 or -1!"
        end
        answer = @api.post("/post/vote.json","id=#@id&score=#{direction}&#@login").parse
        score,success,change = answer["score"],answer["success"],answer["change"]
      rescue
        raise E621APIError, E621.error(@id)
      end
      if success then
        puts "  #@id #{score.to_i-change} -> #{score}"
      else
        $stderr.puts "Vote failed on #@id: #{answer["reason"]}."
        @log.error "Vote failed on #@id: #{answer["reason"]}."
      end
    end
    # Favorite or unfavorite a post.
    def fav(fav=true)
      begin
        com,sign = fav ? ["create","+"] : ["destroy","-"]
        # Decide if to favorite or remove a favorite.
        answer = @api.post("/favorite/#{com}.json","id=#@id",{"cookie"=>@cookie}).parse
        if answer["success"] then # If it works, show it to the user.
          puts "#{sign}Favorite".bold+" succeded on #@id."
        else # If not, show the user that it failed.
          puts "#{sign}Favorite".bold+" failed on #@id: #{answer["reason"]}"
        end
      rescue
        raise E621APIError, E621.error(@id)
      end
    end
    # Just a custom to_json function.
    def to_json
      {"id"=>@id, "file_url"=>@file_url, "created_at"=>@created_at}
    end
    # A real download function for Post itself should be worth it.
    def download(pre_string="")
      @file = File.basename(@file_url)
      # If we don't cache, just get stuff straight from the source, all
      # the time.
      download_helper(pre_string)
    end
    # This function presents most information you can see on the post page on
    # e621.net. Some options are left out, as they don't make sense. Like notes.
    def show
      # This function was too big, so it got split up in several smaller
      # (private) functions.
      begin
        @tags = @tags.split(" ").map{|t|Tag.new(t)}
        faved = @api.post("/favorite/list_users.json","id=#@id&#@login").parse["favorited_users"].split(",").include?(@passwd["name"])
        puts " "*2+"Post ##{@id.to_s.bold}",""
        puts " "*4+"Status: #{@status.capitalize.bold}"
        ctime = Time.at(@created_at).strftime("%b %e,%Y %I:%M %p")
        puts " "*4+"Posted: #{ctime.bold} by #@author"
        show_rating
        show_score
        puts " "*4+"Parent ID: #{@parent_id.to_s.bold}" if @parent_id
        puts " "*4+"This post has children posts.".bold if @has_children
        if @description != String.new then
          puts " "*4+"Description: #{@description.to_constr(16)}"
        end
        puts " "*4+"Favorite: #{faved ? "Yes".bold("green") : "No".bold("red")}"
        show_tags
      rescue
        raise InternalError, "Post ##@id raised an error: #$!."
      end
    end
    private
    # A little helper function for file downloads.
    def download_helper(pre_string)
      http = Net::HTTP.new(@file_url.match(%r[(?<=//).+?(?=/)]).to_s,443)
      http.use_ssl = true
      length, body = 2,""
      until length <= body.length do
        head,body = http.get(@file_url.sub(/.+?net/,""))
        length = head["content-length"].to_i
      end
      File.open("#{pre_string}#{@id.pad(7)}.#{@file}","w"){|f|f.print body}
      return body
    end
    # Show the rating of a post.
    def show_rating
      rating = case @rating
               when "s" then "Safe".bold
               when "q" then "Questionable".bold("blue")
               when "e" then "Explicit".bold("red")
               else "Unknown"
               end
      puts " "*4+"Rating: #{rating}"
    end
    # Displays the score of a post.
    def show_score
      @score = @score.to_i
      score = if @score > 0 then "green"
              elsif @score < 0 then "red"
              else nil
              end
      puts " "*4+"Score: #{@score.to_s.bold(score)}"
    end
    # Sort and display all tags associated to this post.
    def show_tags
      types = ["Artist","Copyright","Character","Species","General"]
      types.each do |type|
        case type
        when "General"    then puts type.bold;type = 0
        when "Artist"     then puts type.bold("yellow");type = 1
        when "Copyright"  then puts type.bold("purple");type = 3
        when "Character"  then puts type.bold("green");type = 4
        when "Species"    then puts type.bold("red");type = 5
        end
        tags = Array.new
        @tags.each do |t|
          next if !t.name.is_a?(String)
          name,count = t.name.sub(/\s+$/,"").pad(17), t.count.to_s
          tags << "#{" "*(7-count.length)}#{count} #{name}" if t.type == type
        end
        while (t = tags.shift(3)) != [] do
          line = " "*2+t.map{|tag|tag}.join(" ")
          puts line
        end
      end
    end
  end
end
