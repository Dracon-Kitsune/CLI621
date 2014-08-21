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
    attr_reader :name,:id,:posts,:is_public,:post_count,:description
    def initialize(pool)
      @api = API.new("pool")
      if pool.is_a?(Fixnum) then
        pool = @api.post("show",{"id"=>pool})
      else
        raise ArgumentError, "Class #{pool.class} is not recognized in this context."
      end
      pool.each do |k,v|
        instance_variable_set("@#{k}".to_sym,v)
      end
      @name.gsub!("_"," ")
    end
    def is_public?
      @is_public
    end
    # Update function to update this perticular pool.
    def update(name,is_public,description)
      is_public = is_public ? 1 : 0
      r = {"id"=>@id,"pool"=>{"name"=>name,"is_public"=>is_public,"description"=>description}}
      # implement a proper error handling for returned API errors.
    end
    # Show all information of this pool.
    def show
      creator = User.new(@user_id)
      puts "#{@name.bold} (#@id)",""
      puts " "*2+"Posts".bold+": #{@post_count}"
      puts " "*2+"Created at".bold+": #{Time.at(@created_at["s"])}"
      puts " "*2+"Creator".bold+": #{creator.name}"
      puts " "*2+"Public".bold+": #{@is_public ? "Yes".bold("green") : "No".bold("yellow")}"
      puts " "*2+"Last updated".bold+": #{Time.at(@updated_at["s"])}"
      puts " "*2+"Description".bold+":",@description.indent(4)
    end
    # Initialize configuration class wide, so not each instance needs it too.
    def self.init(config,paths)
      @@config,@@paths = config,paths
    end
  end
end
