require './payload_filter'
require 'optparse'

class Runner
  def initialize(
    pattern,
    start_date,
    end_date,
    name,
    tag = pattern
  )

    start_date = start_date ?  Date.parse(start_date) : Date.today
    end_date = (start_date && end_date) ? Date.parse(end_date) : Date.today 

    options = {
      start_date: start_date,
      end_date: end_date,
    }
   
    payload_filter = PayloadFilter.new(name, tag, pattern, options)
    payload_filter.fetch
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

Runner.new(ARGV[0], ARGV[1], ARGV[2], ARGV[3]="Report")