# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class FormFill < Common::Base
    attribute :attachment_types, Array[Preneeds::AttachmentType]
    attribute :branches_of_services, Array[Preneeds::BranchesOfService]
    attribute :cemeteries, Array[Preneeds::Cemetery]
    attribute :states, Array[Preneeds::State]
    attribute :discharge_types, Array[Preneeds::DischargeType]
    # Note: Getting military ranks for all branches of service is slow, even when cached. Perhaps
    # Rely on the military_ranks controller, which the FE would call when the user selects a branch of service.
    # attribute :military_ranks, Hash[String => Array[Preneeds::BranchesOfService]]

    # There is no natural id.
    def id
      Time.now.utc.to_i
    end
  end
end
