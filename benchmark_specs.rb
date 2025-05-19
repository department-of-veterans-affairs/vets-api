# benchmark_hca_tests.rb
require 'benchmark'

x = 5 # change to however many times you want to run
times = []

rspec_command = "
  bundle exec rspec \
    $(find spec -type d -path '*ezr*') \
"
#     --format documentation --profile

# bundle exec rspec \
# $(find spec -type d -path '*1010cg*') \
# $(find spec -type f -name '*caregiver*.rb') \
# $(find spec -type d -path '*ezr*') \
# $(find spec -type d -path '*hca*') \
# $(find spec -type f -name '*health_care_application*_spec.rb') \
# $(find spec -type f -name '*va1010ez*_spec.rb') \

x.times do |i|
  puts "\n🚀 Run ##{i + 1}"
  time = Benchmark.realtime do
    system(rspec_command)
  end
  puts "⏱️  Time: #{time.round(2)}s"
  times << time
end

average = times.sum / x
puts "\n📊 Average runtime over #{x} runs: #{average.round(2)} seconds"
