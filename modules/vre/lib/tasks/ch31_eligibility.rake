# frozen_string_literal: true

require_relative '../../app/services/vre/service'
require_relative '../../app/services/vre/configuration'

class Ch31Eligibility < VRE::Service
  configuration VRE::Configuration
  STATSD_KEY_PREFIX = 'api.res.eligibility'

  def initialize(url = nil)
    @url = url
    super()
  end

  private

  def end_point
    # allow override of url for development purposes
    @url || "#{Settings.res.base_url}/suite/webapi/chapter31-eligibility-details-search"
  end
end

# e.g. bundle exec rake 'vre:ch31_eligibility:connect[{"icn":"1234567890V123456"}]'
namespace :vre do
  namespace :ch31_eligibility do
    desc 'Tests connection to ch31 eligibility details endpoint in RES'
    task :connect, %i[payload url] => :environment do |_cmd, args|
      client = Ch31Eligibility.new(args[:url])
      response = client.send_to_res(payload: args[:payload])
      puts response
    end
  end
end
