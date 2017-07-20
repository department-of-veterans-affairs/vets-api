# frozen_string_literal: true
module Preneeds
  class FormFillSerializer < ActiveModel::Serializer
    has_many :attachment_types, each_serializer: ::Preneeds::AttachmentTypeSerializer
    has_many :branches_of_services, each_serializer: ::Preneeds::BranchesOfServiceSerializer
    has_many :cemeteries, each_serializer: ::Preneeds::CemeterySerializer
    has_many :discharge_types, each_serializer: ::Preneeds::DischargeTypeSerializer
    has_many :states, each_serializer: ::Preneeds::StateSerializer

    attribute :attachment_types
    attribute :branches_of_services
    attribute :cemeteries
    attribute :discharge_types
    attribute :states
  end
end
