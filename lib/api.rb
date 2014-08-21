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
    def self.init(login,cookie)
      @@login,@@cookie = login,cookie
    end
    # Variable mod is the module (Post, Pool, Set,...) this API is called for.
    def initialize(mod)
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
        raise
      rescue Timeout::Error
        raise
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
  end
end
