# frozen_string_literal: true

require_relative 'mvi_profile_identity'
require_relative 'mvi_profile_ids'
require 'identity/model/inspect'

module MPI
  module Models
    class MviProfileRelationship
      include ActiveModel::Model
      include ActiveModel::Attributes
      include Identity::Model::Inspect
      include MviProfileIdentity
      include MviProfileIds
    end
  end
end
