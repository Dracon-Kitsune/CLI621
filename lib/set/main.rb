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
  class Main
    private
    # Do module specific tasks here.
    def mod_init
      Set.init(@config,@paths)
      Post.init(@config,@paths)
      Readline.completion_proc = proc do |s|
        words = ["list","listiby post","listby user","listby maintainer"]
        s = Regexp.escape(s)
        words.grep(/^#{s}/)
        # A function to get some useful completion feed back should be here.
      end
      Readline.completer_word_break_characters  = " "
      Readline.completion_append_character      = " "
      @prompt = "/pool"
    end
    # List certain sets.
    def list(buf)
      if buf.first == "post" then
        buf.shift
      end
    end
    alias :listby, :list
  end
end
