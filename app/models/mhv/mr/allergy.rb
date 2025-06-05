# frozen_string_literal: true

require 'common/models/base'

module MHV
  module MR
    class Allergy < MHV::MR::FHIRRecord
      include RedisCaching

      redis_config REDIS_CONFIG[:medical_records_cache]

      attribute :id,               String
      attribute :name,             String
      attribute :date,             String # Pass on as-is to the frontend
      attribute :categories,       String, array: true
      attribute :reactions,        String, array: true
      attribute :location,         String
      attribute :observedHistoric, String # 'o' or 'h'
      attribute :notes,            String
      attribute :provider,         String

      default_sort_by date: :desc

      def self.map_fhir(fhir)
        {
          id: fhir.id,
          name: fhir.code&.text,
          date: fhir.recordedDate,
          categories: categories(fhir),
          reactions: reactions(fhir),
          location: location_name(fhir),
          observedHistoric: observed_historic(fhir),
          notes: note_text(fhir),
          provider: provider(fhir)
        }
      end

      def self.categories(fhir)
        fhir.category || []
      end

      def self.reactions(fhir)
        Array(fhir.reaction).flat_map do |r|
          Array(r.manifestation).map { |m| m&.text }.compact
        end
      end

      def self.location_name(fhir)
        ref = fhir.recorder&.extension&.first&.valueReference&.reference
        find_contained(fhir, ref, type: 'Location')&.name
      end

      def self.observed_historic(fhir)
        ext = Array(fhir.extension).find { |e| e.url&.include?('allergyObservedHistoric') }
        ext&.valueCode
      end

      def self.note_text(fhir)
        fhir.note&.first&.text
      end

      def self.provider(fhir)
        fhir.recorder&.display
      end
    end
  end
end
