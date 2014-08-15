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

require "json"

class String
  # Make json parsing a lot easier and less to write.
  def parse
    JSON.parser.new(self).parse
  end
  # Remove all tags inside of a string.
  def clean
    self.gsub(/<.+?>/,"")
  end
  # Trim or expand a string to a certain length.
  def pad(c,s=" ")
    if self.length > c then
      self[0,c-3]+"..."
    elsif self.length < c then
      self+s.to_s*(c-self.length)
    else
      self
    end
  end
  # Make a string bold and colorful, with colors a user can understand. Not
  # those cryptic numbers.
  def bold(color=nil)
    c = case color
    when "black"  then  "\e[30;1m"
    when "red"    then  "\e[31;1m"
    when "green"  then  "\e[32;1m"
    when "yellow" then  "\e[33;1m"
    when "blue"   then  "\e[34;1m"
    when "purple" then  "\e[35;1m"
    when "cyan"   then  "\e[36;1m"
    else                "\e[37;1m"
    end
    c+self+"\e[0m"
  end
  # Same as bold, but just make a string colorful.
  def color(color=nil)
    c = case color
    when "black"  then  "\e[30;0m"
    when "red"    then  "\e[31;0m"
    when "green"  then  "\e[32;0m"
    when "yellow" then  "\e[33;0m"
    when "blue"   then  "\e[34;0m"
    when "purple" then  "\e[35;0m"
    when "cyan"   then  "\e[36;0m"
    else                "\e[37;0m"
    end
    c+self+"\e[0m"
  end
  # It is just convenient to have a custom to_bool function. Only "true" gets
  # turned into true, anything else is false.
  def to_bool
    if self.downcase == "true" then
      true
    else
      false
    end
  end
end
