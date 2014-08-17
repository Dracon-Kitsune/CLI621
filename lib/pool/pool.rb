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
  class Pool
    attr_reader :name,:id,:posts,:is_public,:post_count
    def initialize(pool)
      E621.log.debug("Pool is given as a #{pool.class} object and has the following content: #{pool.inspect}.")
      http = E621.connect
      if pool.is_a?(Hash) then
        pool.each do |k,v|
          instance_variable_set("@#{k}".to_sym,v)
        end
        @name.gsub!("_"," ")
      elsif pool.is_a?(Fixnum) then
      else raise ArgumentError, "Class #{pool.class} is not recognized in this context."
      end
    end
    # Show all information of this pool.
    def show
      #puts "#{@name.bold} (#@id)",""
      #puts " "*2+"Posts: #{@post_count}"
      #puts " "*2+"Created at: #{Time.at(@created_at["s"]).strftime("%b %e,%Y %I:%M %p")}"

    end
    # Initialize configuration class wide, so not each instance needs it too.
    def self.init(config,pathes)
      @@config,@@pathes = config,pathes
    end

  end
end
