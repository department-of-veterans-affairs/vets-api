# frozen_string_literal: true

module Facilities
  class Point
    attr_reader :x, :y, :facility

    def initialize(x, y, facility)
      @x = x
      @y = y
      @facility = facility
    end

    def within?(bbox)
      return false if @x.nil? || @y.nil?
      x_min, x_max = min_max(bbox[0], bbox[2])
      y_min, y_max = min_max(bbox[1], bbox[3])
      x_min < @x && @x < x_max &&
        y_min < @y && @y < y_max
    end

    def min_max(x, y)
      x < y ? [x, y] : [y, x]
    end

    def dist_from_center(bbox)
      center_x = (bbox[0] + bbox[2]) / 2.0
      center_y = (bbox[1] + bbox[3]) / 2.0
      Math.sqrt((@x - center_x)**2 + (@y - center_y)**2)
    end
  end
end
