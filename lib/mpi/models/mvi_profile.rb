# frozen_string_literal: true

require_relative 'mvi_profile_address'
require_relative 'mvi_profile_identity'
require_relative 'mvi_profile_ids'
require_relative 'mvi_profile_relationship'

module MPI
  module Models
    class MviProfile
      include ActiveModel::API
      include ActiveModel::Attributes
      include ActiveModel::Serializers::JSON
      include MviProfileIdentity
      include MviProfileIds

      attribute :search_token, :string
      attribute :relationships, array: true, default: []
      attribute :id_theft_flag, :boolean
      attribute :transaction_id, :string

      def [](key)
        attributes[key.to_s]
      end

      def to_h
        attributes.symbolize_keys
      end
    end
  end
end
