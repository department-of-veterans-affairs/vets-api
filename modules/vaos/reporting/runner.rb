require './filter'
require 'optparse'

class Runner
  def initialize(
    filter,
    pattern,
    name,
    tag = pattern
  )

    start_date = start_date ?  Date.parse(start_date) : Date.today
    end_date = (start_date && end_date) ? Date.parse(end_date) : Date.today 

    options = {
      start_date: start_date,
      end_date: end_date,
    }

    filter_type = Filter.new(name, tag, filter, pattern, options)
    filter_type.fetch
  end
end

# options = {}

# OptionParser.new do |opts|
#   opts.banner = "Usage: example.rb [options]"

#   opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
#     options[:verbose] = v
#   end
# end.parse!

# p options

Runner.new(ARGV[0], ARGV[1], ARGV[2], ARGV[3])