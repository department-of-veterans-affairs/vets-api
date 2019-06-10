# frozen_string_literal: true

module EMIS
  module Models
    # EMIS veteran status data
    #
    # @!attribute title38_status_code
    #   @return [String] veteran status of person under Title 38
    #     definition.
    #       V1 => Title 38 Veteran
    #       V2 => VA Beneficiary
    #       V3 => Military Person, Not Title 38 Veteran, Not DoD Affiliate [See note below on IIT]
    #       V4 => Military or Beneficiary Status Unknown
    #       V5 => EDI PI Not Known in VADIR (used in service calls only; not a stored value)
    #       V6 => Military Person, Not Title 38 Veteran, DoD Affiliate (indicates current military)
    #       V7 => Military Person, Not Title 38 Veteran, Not DoD Affiliate, "Bad Paper"
    #         Discharge(s) [See note below on IIT]
    #       * Interoperability Indicator Type (IIT) [MVI can treat V6 and V7 as V3 if they so
    #         choose; combination meets original V3 definition]
    # @!attribute post911_deployment_indicator
    #   @return [String] "Y" if veteran was deployed post 9/11, "N" otherwise
    # @!attribute post911_combat_indicator
    #   @return [String] "Y" if veteran served in combat post 9/11, "N" otherwise
    # @!attribute pre911_deployment_indicator
    #   @return [String] "Y" if veteran was deployed pre 9/11, "N" otherwise
    class VeteranStatus
      include Virtus.model

      attribute :title38_status_code, String
      attribute :post911_deployment_indicator, String
      attribute :post911_combat_indicator, String
      attribute :pre911_deployment_indicator, String
    end
  end
end
