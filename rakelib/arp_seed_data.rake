# frozen_string_literal: true

require_relative '../lib/accredited_representation/seed_data'

namespace :arp do
  desc 'Seed VerifiedRepresentative data for staging'
  task :seed_representative, [:test_rep_email] => [:environment] do |_, args|
    raise 'No representative email provided' unless args[:test_rep_email]

    # Create VerifiedRepresentative and AccreditedIndividual for logging into accredited_representative_portal
    ogc_registration_number = '123'
    poa_code = '678'
    individual_type = 'representative'

    AccreditedRepresentation::SeedData.create_rep_data(args[:test_rep_email],
                                                       ogc_registration_number,
                                                       poa_code,
                                                       individual_type)
  end
end
