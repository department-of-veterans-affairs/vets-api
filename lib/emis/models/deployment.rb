# frozen_string_literal: true

module EMIS
  module Models
    class DeploymentLocation
      include Virtus.model

      attribute :segment_identifier, String
      attribute :country, String
      attribute :iso_alpha3_country, String
      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :termination_reason_code, String
      attribute :transaction_date, Date

      def date_range
        begin_date..end_date
      end
    end

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
