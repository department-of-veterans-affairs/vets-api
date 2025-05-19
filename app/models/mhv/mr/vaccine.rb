# frozen_string_literal: true

module MHV
  module MR
    class Vaccine < MHV::MR::FHIRRecord
      attribute :id,            String
      attribute :name,          String
      attribute :date_received, String # Pass on as-is to the frontend
      attribute :location,      String
      attribute :manufacturer,  String
      attribute :reactions,     String
      attribute :notes,         Array

      ##
      # Map from a FHIR::Immunization resource
      #
      def self.map_fhir(fhir)
        # extract location.name
        loc_res = find_contained(fhir, fhir.location&.reference, type: 'Location')
        # extract reaction Observation.code.text
        obs_res = find_contained(fhir, fhir.reaction&.first&.detail&.reference, type: 'Observation')

        {
          id: fhir.id,
          name: fhir.vaccineCode&.text,
          date_received: fhir.occurrenceDateTime,
          location: loc_res&.name,
          manufacturer: fhir.manufacturer&.display,
          reactions: obs_res&.code&.text,
          notes: (fhir.note || []).map(&:text)
        }
      end
    end
  end
end
