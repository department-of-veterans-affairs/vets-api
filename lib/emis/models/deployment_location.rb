# frozen_string_literal: true

module EMIS
  module Models
    # EMIS veteran deployment locations data
    class DeploymentLocation
      include Virtus.model

      attribute :segment_identifier, String
      attribute :country, String
      attribute :iso_alpha3_country, String
      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :termination_reason_code, String
      attribute :transaction_date, Date

      # Date range of deployment
      # @return [Range] Date range of deployment
      def date_range
        begin_date..end_date
      end
    end
  end
end
