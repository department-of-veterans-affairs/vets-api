# frozen_string_literal: true

namespace :arp do
  desc 'Seed VerifiedRepresentative data for staging'
  task :seed_representative, [:rep_email] => [:environment] do |_, args|
    raise 'No representative email provided' unless args[:test_rep_email]

    # Create VerifiedRepresentative and AccreditedInvidial for logging into accredited_representative_portal
    ogc_registration_number = '123'
    poa_code = '678'
    individual_type = 'representative'

    accredited_individual = AccreditedIndividual.find_or_initialize_by(registration_number: ogc_registration_number)
    accredited_individual.update!(ogc_id: SecureRandom.uuid,
                                  poa_code:,
                                  individual_type:,
                                  email:)

    verified_rep = AccreditedRepresentativePortal::VerifiedRepresentative.find_or_initialize_by(email: test_rep_email)
    verified_rep.update!(ogc_registration_number:)
  end
end
