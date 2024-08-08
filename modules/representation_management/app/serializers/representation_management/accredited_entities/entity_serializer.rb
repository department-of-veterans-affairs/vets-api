# frozen_string_literal: true

module RepresentationManagement
  module AccreditedEntities
    class EntitySerializer
      include JSONAPI::Serializer

      def initialize(object)
        @object = object
      end

      def serializable_hash
        serializer_class.new(@object).serializable_hash
      end

      private

      def serializer_class
        case @object
        when AccreditedIndividual
          RepresentationManagement::AccreditedEntities::IndividualSerializer
        when AccreditedOrganization
          RepresentationManagement::AccreditedIndividuals::OrganizationSerializer
        else
          raise "Unknown object type: #{@object.class}"
        end
      end
    end
  end
end
