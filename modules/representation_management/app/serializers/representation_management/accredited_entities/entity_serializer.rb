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
        p "Object: #{@object}"
        case @object
        when AccreditedIndividual
          RepresentationManagement::AccreditedIndividuals::IndividualSerializer
        when AccreditedOrganization
          RepresentationManagement::AccreditedOrganizations::OrganizationSerializer
        else
          raise "Unknown object type: #{@object.class}"
        end
      end
    end
  end
end
