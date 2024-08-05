# frozen_string_literal: true

module Formatters
  class TimeFormatter
    ##
    # format `secs` into a human readable output - X days Y hours Z minutes S seconds
    # 0 will return ""
    #
    # @param secs [Float|Integer] the number of seconds to format, eg: 940913.38729661
    #
    # @return [String] the human readable string
    #
    def self.humanize(secs)
      [[60, :seconds], [60, :minutes], [24, :hours], [Float::INFINITY, :days]].map do |count, name|
        if secs.positive?
          secs, num = secs.divmod(count)

          num = num.to_i
          unit = num > 1 ? name : name.to_s.chomp('s')
          "#{num} #{unit}" unless num.zero?
        end
      end.compact.reverse.join(' ')
    end

    # class
  end
  # module
end
