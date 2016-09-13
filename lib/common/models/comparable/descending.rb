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

    def <=>(other)
      -(obj <=> other.obj)
    end
  end
end
