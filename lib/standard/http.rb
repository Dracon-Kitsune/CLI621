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
  class HTTP
    def initialize(host="e621.net",port=443)
      @http = Net::HTTP.new(host,port)
      @http.use_ssl = true if port == 443
    end
    # Small wrapper function for post calls. This way a proper logging is
    # guaranteed.
    def post(url,request,hash={})
      E621.log.debug("Downloading #{url}?#{request}.")
      head,body = @http.post(url,request,hash)
      E621.log.debug("Downloaded #{url}?#{request}.")
      code = head.code.to_i
      if code > 300 then
        body = errorcode(code) # Emulate a proper API response!
      end
      return body
    end
    # Small wrapper function for get calls. This way a proper logging is
    # guaranteed.
    def get(url,hash={})
      head,body = @http.get(url,hash)
      code = head.code.to_i
      if code > 300 then
        body = errorcode(code) # Emulate a proper API response!
      end
      return body
    end
    def errorcode(code)
      body = {"success"=>false,"reason"=>""}
      body["reason"] =  if code >= 300 && code < 400 then
                          "We got redirected!"
                        elsif code == 404 then
                          "File not found!"
                        elsif code >= 400 && code < 500 then
                          "We made a bad request!"
                        elsif code >= 500 then
                          E621.log.error("Server side error! Url used: #{url} (#{code})")
                          raise E621ServerError, code
                        else
                          raise E621ServerError, "Got strange HTTP code back: #{code}"
                        end
    end
  end
end
