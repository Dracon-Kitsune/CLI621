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

class Fixnum
  def to_kb
    (self/1024.0).round(2)
  end

  def to_mb
    (self/(1024*1024.0)).round(2)
  end

  def pad(c,s=0)
    "#{s}"*(c-self.to_s.length)+self.to_s
  end
end
