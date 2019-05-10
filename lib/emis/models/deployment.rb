# frozen_string_literal: true

module EMIS
  module Models
    # EMIS veteran deployments data
    #
    # @!attribute segment_identifier
    #   @return [String] identifier that is used to ensure a unique
    #     key on each deployment location record
    class Deployment
      include Virtus.model

      attribute :segment_identifier, String
      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :project_code, String
      attribute :termination_reason, String
      attribute :transaction_date, Date
      attribute :locations, Array[DeploymentLocation]
    end
  end
end
