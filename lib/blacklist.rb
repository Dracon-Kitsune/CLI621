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

class Blacklist < Tag
  def initialize(e621)
    super(e621)
    @help = [
      "list",
      "add tag1 tag2 tag3 ...",
      "remove tag1 tag2 tag3 ..."
    ]
  end

  def list
    $stdout.puts "These are all blacklisted tags:","#{CLI::BOLD}#{@e621.blacklist.join("#{CLI::NORMAL}, #{CLI::BOLD}")}#{CLI::NORMAL}".to_constr(@e621.termwidth,2)
  end
end
