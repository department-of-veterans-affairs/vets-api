# frozen_string_literal: true

require_relative '../lib/accredited_representation/seed_data'

namespace :arp do
  desc 'Seed VerifiedRepresentative data for staging'
  task :seed_representative, %i[test_rep_email ogc poa indiv_type] => [:environment] do |_, args|
    raise 'No representative email provided' unless args[:test_rep_email]
    raise 'No representative OGC code provided' unless args[:ogc]
    raise 'No representative POA code provided' unless args[:poa]
    raise 'No representative individual_type provided' unless args[:test_rep_email]

    # Create PilotRepresentative and AccreditedIndividual for logging into accredited_representative_portal

    AccreditedRepresentation::SeedData.create_rep_data(args[:test_rep_email],
                                                       args[:opc],
                                                       args[:poa],
                                                       args[:indiv_type])
  end
end
