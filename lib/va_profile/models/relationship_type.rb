# frozen_string_literal: true

require_relative 'base'

module VAProfile
  module Models
    class RelationshipType < Base
      attribute :relationship_type_name, String

      def self.build_from(body)
        new(relationship_type_name: body[:relationship_type_name])
      end
    end
  end
end
