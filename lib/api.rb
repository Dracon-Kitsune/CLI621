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
      @http = Net::HTTP.new("e621.net",443)
      @http.use_ssl = true
      @mod = mod
    end
    # Send commands to API and parse all answers, even errors.
    def post(action,request)
      r = request2body(r)
      begin
        json = @http.post("/#@mod/#{action}.json","r").body.parse
        if json.include?("success") && !json["success"] then
          raise E621APIError,json["reason"]
        end
      end
    end
    private
    # This helper function provides the functionality of translating Ruby Hashes
    # into HTTP POST body strings.
    def request2body(r)
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
      s += "&#@@login"
    end
  end
end
