# frozen_string_literal: true

module EMIS
  module Models
    # EMIS veteran deployment locations data
    # @!attribute segment_identifier
    #   @return [String] identifier that is used to ensure a unique key on each
    #     deployment location record.
    # @!attribute country
    #   @return [String] alpha-2 code that represents the country of the person's location.
    #     The valid values also include dependencies and areas of special sovereignty.
    # @!attribute iso_alpha3_country
    #   @return [String] ISO alpha 3 code representing the country of deployment.
    # @!attribute begin_date
    #   @return [Date] start date for the deployment to this location.
    # @!attribute end_date
    #   @return [Date] end date for the deployment to this location.
    # @!attribute termination_reason_code
    #   @return [String] code that represents the reason why the deployment at that location
    #     terminated.
    #       C => Completion of Deployment Period at a location
    #       W => Not Applicable
    # @!attribute transaction_date
    #   @return [Date] date for the transaction updating deployment location data.
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
