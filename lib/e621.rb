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
  # several helper functions to globalize variables
  def self.debug=(d)
    @@debug = d
  end

  def self.debug
    @@debug
  end

  def self.log=(l)
    @@log = l
  end

  def self.log
    @@log
  end
  # This is a general error handling method and should be put into an error
  # class.
  def self.error(id)
    if $!.to_s.length < 512 then
      "Post ##{id} caused an error: #$!"
    else
      $!.to_s =~ /<pre>.+<\/pre>/
      err = $~.to_s
      err = err.gsub(/<pre>|<\/pre>/,"").gsub("&gt;",">").gsub("&lt;","<").gsub("&#39","'")
      "Post ##{id} caused a remote error: #{err}."
    end
  end
end
