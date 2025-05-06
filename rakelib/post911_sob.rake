# frozen_string_literal: true

require 'post911_sob/dgib/client'

namespace :post911_sob do
  namespace :dgib do
    desc 'Test connection between vets-api and DGIB claimant-service'
    task :connect, %i[claimant_id base_url] => :environment do |_cmd, args|
      args.with_defaults(base_url: Settings.dgi.post911_sob.claimants.url)

      # Allow for base url to be overridden for testing purposes
      Settings.dgi.post911_sob.claimants.url = args[:base_url]

      client = Post911SOB::DGIB::Client.new(args[:claimant_id])

      puts client.get_entitlement_transferred_out
    end
  end
end
