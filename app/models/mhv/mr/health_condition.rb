# frozen_string_literal: true

require 'common/models/base'

module MHV
  module MR
    class HealthCondition < MHV::MR::FHIRRecord
      attribute :id,        String
      attribute :name,      String
      attribute :date,      String # Pass on as-is to the frontend
      attribute :provider,  String
      attribute :facility,  String
      attribute :comments,  Array

      def self.map_fhir(fhir)
        facility_ref  = fhir.recorder&.extension&.first&.valueReference&.reference
        provider_ref  = fhir.recorder&.reference
        {
          id: fhir.id,
          name: fhir.code&.text,
          date: fhir.recordedDate,
          facility: find_contained(fhir, facility_ref, type: 'Location')&.name,
          provider: find_contained(fhir, provider_ref, type: 'Practitioner')&.name&.first&.text,
          comments: (fhir.note || []).map(&:text)
        }
      end
    end
  end
end
