# frozen_string_literal: true

require 'common/models/attribute_types/date_time_string'
require_relative 'mvi_profile_address'
require_relative 'mvi_profile_identity'
require_relative 'mvi_profile_ids'
require_relative 'mvi_profile_relationship'

module MPI
  module Models
    class MviProfile
      include Virtus.model
      include MviProfileIdentity
      include MviProfileIds

      attribute :search_token, String
      attribute :relationships, Array[MviProfileRelationship]
      attribute :id_theft_flag, Boolean
      attribute :transaction_id, String
    end
  end
end
