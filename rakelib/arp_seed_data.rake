# frozen_string_literal: true

namespace :arp do
  desc 'Seed VerifiedRepresentative data for staging'
  task :seed_representative, [:rep_email] => [:environment] do |_, args|
    raise 'No representative email provided' unless args[:rep_email]

    # Create VerifiedRepresentative and AccreditedInvidial for logging into accredited_representative_portal
    ogc_registration_number = '12345'

    accredited_individual = AccreditedIndividual.find_or_initialize_by(registration_number: ogc_registration_number)
    accredited_individual.poa_code = 678
    accredited_individual.save(validate: false)

    verified_rep = VerifiedRepresentative.find_or_initialize_by(email: rep_email)
    verified_rep.save(validate: false)
  end
end
