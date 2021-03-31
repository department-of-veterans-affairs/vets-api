# frozen_string_literal: true

require_relative 'mvi_profile_identity'
require_relative 'mvi_profile_ids'

module MPI
  module Models
    class MviProfileRelationship
      include Virtus.model
      include MviProfileIdentity
      include MviProfileIds
    end
  end
end
