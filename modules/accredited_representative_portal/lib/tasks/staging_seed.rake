# frozen_string_literal: true

require_relative 'seed/staging_seed'

namespace :accredited_representative_portal do
  desc 'Seeds POA requests using existing organizations and representatives'
  task seed_poa_requests: :environment do
    AccreditedRepresentativePortal::StagingSeeds.run
  end
end
