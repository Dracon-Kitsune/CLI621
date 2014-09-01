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
  class API
    # Perform an API and site login, to get maximum access.
    def self.login(paths,auto)
      #Load all user credentials into one variable.
      passwd = nil
      File.open(paths["pass"]){|f|passwd=f.read.parse}
      @@login,@@cookie = passwd["login"],passwd["cookie"]
      http = HTTP.new
      name,pass = String.new, String.new
      # Perform a re-login if the last time is older than x days. Or if there is
      # no cookie.
      if (Time.now.to_i-passwd["last_login"].to_i) > 60*60*24*3 || !@@cookie then
        if auto then
          http.get("/user/logout",{"cookie"=>@@cookie.to_s}) if @@cookie
          if passwd["name"] != "" && passwd["pass"] != "" then
            name,pass = passwd["name"],passwd["pass"]
          else
            puts "No user data found. Please provide user data."
            name,pass = get_credentials
            passwd["name"],passwd["pass"] = name,pass
            # Store that data for later use.
          end
        else
          name,pass = get_credentials
        end
        request = "name=#{name}&password=#{pass}"
        body = http.post("/user/login.json",request).parse
        if body.has_key?("success") && (!body["success"] || body["success"] = "failed") then
          raise AuthentificationError, "Username or password wrong!"
        else
          @@login = "login=#{body["name"]}&password_hash=#{body["password_hash"]}"
          passwd["login"] = @login # Save login string for later use.
        end
        request = "url=&user[name]=#{passwd["name"]}&user[password]=#{passwd["pass"]}&user[roaming]=1"
        # Log in user on site, after logging into API is done.
        head = http.head("/user/authenticate",request)
        @@cookie = head["set-cookie"]
        passwd["cookie"] = @@cookie 
        passwd["last_login"] = Time.now.to_i
        # Write everything back!
        File.open(paths["pass"],"w"){|f|f.print passwd.to_json}
      end
      return passwd["name"]
    end
    # Variable mod is the module (Post, Pool, Set,...) this API is called for.
    def initialize(mod,paths=nil,auto=true)
      @http = HTTP.new
      @mod = mod
    end
    # Send commands to API and parse all answers, even errors.
    def post(action,request,cookie=false)
      r,tries = request2body(request,cookie),0
      begin
        json = if cookie then
                 @http.post("/#@mod/#{action}.json",r,{"cookie"=>@@cookie}).parse
               else
                 @http.post("/#@mod/#{action}.json",r).parse
               end
        if json.include?("success") && !json["success"] then
          raise E621APIError,json["reason"]
        end
      rescue E621APIError => e
        E621.log.info("#@mod/#{action} failed: #{e.to_s}")
      rescue Timeout::Error
        sleep 2**tries
        tries += 1
        E621.log.debug("#@mod/#{action} failed: #{e.class}")
        raise if tries >= 4
        # if we see more than 4 timeout errors, then there
        # is something wrong
        retry
      end
      return json
    end
    private
    # This helper function provides the functionality of translating Ruby Hashes
    # into HTTP POST body strings.
    def request2body(r,c)
      s = String.new
      r.each do |k,v|
        s += "&" unless s == String.new
        if v.is_a?(Hash) then
          t = String.new
          v.each do |e,a|
            t += "&" unless t == String.new
            t += "#{k}[#{e}]=#{a}"
          end
          s += t
        else
          s += "#{k}=#{v}"
        end
      end
      E621.log.debug("Created request \"#{s}\".")
      s += "&#@@login" if !c
      return s
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
      puts
      return [name,pass]
    end
  end
end
