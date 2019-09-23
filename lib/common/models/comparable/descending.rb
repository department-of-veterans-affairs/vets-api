# frozen_string_literal: true

# This is just a wrapper around an object to compare in descending order
# This is invoked by collection.rb
module Common
  class Descending
    include Comparable
    attr_reader :obj

    def initialize(obj)
      @obj = obj
    end

    # This will always force nil values to the end
    def <=>(other)
      return  0 if !obj && !other.obj
      return  1 unless obj
      return -1 unless other.obj

      -(obj <=> other.obj)
    end
  end
end
