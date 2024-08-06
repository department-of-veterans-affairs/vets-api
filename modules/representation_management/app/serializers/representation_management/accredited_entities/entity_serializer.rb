# frozen_string_literal: true

module RepresentationManagement
  module AccreditedEntities
    class EntitySerializer
      include JSONAPI::Serializer

      def initialize(object)
        p 'RepresentationManagement::AccreditedEntities::EntitySerializer ' * 20, "object: #{object}"
        @object = object
      end

      def serializable_hash
        serializer_class.new(@object).serializable_hash
      end

      private

      def serializer_class
        p "Object: #{@object}", "Object class: #{@object.class.name}"
        case @object
        when AccreditedIndividual
          RepresentationManagement::AccreditedEntities::IndividualSerializer
        when AccreditedOrganization
          RepresentationManagement::AccreditedEntities::OrganizationSerializer
        else
          raise "Unknown object type: #{@object.class}"
        end
      end
    end
  end
end
