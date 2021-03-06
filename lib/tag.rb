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
  class Tag
    attr_reader :type,:count,:id,:name
    def initialize(tag)
      if !tag.is_a?(Hash) && tag.is_a?(String) then
        i = $tags.index{|t|t["name"]==tag}
        tag = $tags[i] if i
      elsif tag.is_a?(Hash) then
      else raise ArgumentError
      end
      @type,@count,@id,@name = tag["type"].to_i,tag["count"].to_i,tag["id"].to_i,tag["name"] if tag
    end
  end
end
