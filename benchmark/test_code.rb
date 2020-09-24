# frozen_string_literal: true

require 'benchmark/ips'

# Enter the code you want to test here

# Example scenario:
#  You've been working on some improvements to EVSS Faraday middleware.
#  You might run something like this:
#
# subject = EVSS::PCIU::Service.new FactoryBot.build(:user, :loa3)
# Benchmark.ips do |bm|
#   bm.report('evss_middleware') do
#     VCR.use_cassette('evss/pciu/email') do
#       subject.get_email_address
#     end
#   end
# end
#
