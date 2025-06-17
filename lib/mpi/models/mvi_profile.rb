# frozen_string_literal: true

require_relative 'mvi_profile_address'
require_relative 'mvi_profile_identity'
require_relative 'mvi_profile_ids'
require_relative 'mvi_profile_relationship'

module MPI
  module Models
    class MviProfile
      include ActiveModel::Model
      include ActiveModel::Attributes
      include MviProfileIdentity
      include MviProfileIds

      attribute :id_theft_flag,  :boolean
      attribute :relationships,  array: true, default: []
      attribute :search_token,   :string
      attribute :transaction_id, :string

      def [](key)
        public_send(key)
      end

      def []=(key, value)
        public_send("#{key}=", value)
      end
    end
  end
end
