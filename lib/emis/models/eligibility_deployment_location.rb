# frozen_string_literal: true

module EMIS
  module Models
    # EMIS Eligibility Deployment Location data
    #
    # @!attribute segment_identifier
    #   @return [String] identifier that is used to ensure a unique key on each deployment
    #     location record.
    # @!attribute country_code
    #   @return [String] ISO alpha2 country code that represents the country of the person's
    #     location. The valid values also include dependencies and areas of special
    #     sovereignty.
    # @!attribute iso_a3_country_code
    #   @return [String] ISO alpha 3 code representing the country of deployment.
    class EligibilityDeploymentLocation
      include Virtus.model

      attribute :segment_identifier, String
      attribute :country_code, String
      attribute :iso_a3_country_code, String
    end
  end
end
