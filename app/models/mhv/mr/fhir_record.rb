# frozen_string_literal: true

require 'vets/model'

module MHV
  module MR
    # Abstract superclass for models built from FHIR resources
    # template class that handles common lookup and construction logic
    class FHIRRecord
      include Vets::Model

      # Build a new instance from a FHIR resource, or return nil if none
      def self.from_fhir(fhir)
        return nil if fhir.nil?

        new(map_fhir(fhir))
      end

      # Subclasses must implement this to return a hash of attributes
      def self.map_fhir(fhir)
        raise NotImplementedError, "#{name}.map_fhir must be implemented by subclass"
      end

      # Locate a contained resource by its reference string ("#id"), optionally filtering by type
      def self.find_contained(fhir, reference, type: nil)
        return nil unless reference && fhir.contained

        target_id = reference.delete_prefix('#')
        resource = fhir.contained.detect { |res| res.id == target_id }
        return nil unless resource
        return resource if type.nil? || resource.resourceType == type

        nil
      end
    end
  end
end
