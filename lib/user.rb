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
  class User
    attr_reader :name, :id, :blacklisted
    def initialize(user)
      @api = API.new("user")
      if user.is_a?(Fixnum) then
        set_vars(@api.post("index",{"id"=>user}).first)
      elsif user.is_a?(String) then
        set_vars(@api.post("index",{"name"=>user}).first)
      elsif user.is_a?(Hash) then
        set_vars(user)
      end
      @created_at = Time.parse(@created_at)
    end
    # Update user data, like blacklists.
    def update
      set_vars(@api.post("index",{"id"=>@id}).first)
    end
    private
    # A little helper to reduce repeative code.
    def set_vars(hash)
      hash.each do |k,v|
        instance_variable_set("@#{k}",v)
      end
    end
  end
end
