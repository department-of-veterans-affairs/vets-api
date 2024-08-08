# frozen_string_literal: true

module AccreditedRepresentation
  module SeedData
    def self.create_rep_data(email, ogc_number, poa_code, individual_type)
      accredited_individual = AccreditedIndividual.find_or_initialize_by(registration_number: ogc_number)
      accredited_individual.update!(ogc_id: SecureRandom.uuid,
                                    poa_code:,
                                    individual_type:,
                                    email:)

      pilot_rep = AccreditedRepresentativePortal::PilotRepresentative.find_or_initialize_by(email:)
      pilot_rep.update!(ogc_registration_number: ogc_number)
    end
  end
end
