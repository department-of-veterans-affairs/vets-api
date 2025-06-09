# frozen_string_literal: true

require_relative 'mvi_profile_identity'
require_relative 'mvi_profile_ids'

module MPI
  module Models
    class MviProfileRelationship
      include ActiveModel::API
      include ActiveModel::Attributes
      include ActiveModel::Serializers::JSON
      include MviProfileIdentity
      include MviProfileIds

      def [](key)
        attributes[key.to_s]
      end

      def to_h
        attributes.symbolize_keys
      end
    end
  end
end
