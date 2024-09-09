# frozen_string_literal: true

module AccreditedRepresentation
  module CreateAccreditedIndividual
    def self.perform(email, ogc_number, poa_code, individual_type)
      accredited_individual = AccreditedIndividual.find_or_initialize_by(registration_number: ogc_number)
      accredited_individual.update!(ogc_id: SecureRandom.uuid,
                                    poa_code:,
                                    individual_type:,
                                    email:)
    end
  end
end
