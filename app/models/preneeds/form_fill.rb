# frozen_string_literal: true
require 'common/models/base'
require 'preneeds/service'

module Preneeds
  class FormFill < Common::Base
    def initialize
      client = Preneeds::Service.new

      self.attachment_types = client.get_attachment_types.to_h
      self.branches_of_services = client.get_branches_of_service.to_h
      self.cemeteries = client.get_cemeteries.to_h
      self.discharge_types = client.get_discharge_types.to_h
      self.states = client.get_states.to_h
    end

    attribute :attachment_types, Array[Preneeds::AttachmentType]
    attribute :branches_of_services, Array[Preneeds::BranchesOfService]
    attribute :cemeteries, Array[Preneeds::Cemetery]
    attribute :states, Array[Preneeds::State]
    attribute :discharge_types, Array[Preneeds::DischargeType]

    # There is no natural id.
    def id
      Digest::SHA2.hexdigest to_json
    end
  end
end
