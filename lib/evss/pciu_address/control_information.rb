# frozen_string_literal: true

require 'vets/model'

module EVSS
  module PCIUAddress
    ##
    # Determines if the user can update their address.
    # Updates are only allowed when all member variables of this object are 'true'
    #
    # @!attribute can_update
    #   @return [Bool] Global flag indicating if the user can update their address.
    #   All other variables in this object must be true for this to be true.
    # @!attribute corp_avail_indicator
    #   @return [Bool] BGS indicator for which BGS has not provided further documentation
    # @!attribute corp_rec_found_indicator
    #   @return [Bool] BGS indicator for which BGS has not provided further documentation
    # @!attribute has_no_bdn_payments_indicator
    #   @return [Bool] Returns true unless the veteran has received BDN payments
    # @!attribute is_competent_indicator
    #   @return [Bool] Returns true if the veteran has not been deemed legally incompetent
    # @!attribute indentity_indicator
    #   @return [Bool] BGS indicator for which BGS has not provided further documentation.
    #   "indentity" is believed to be a misspelling of "identity"
    # @!attribute index_indicator
    #   @return [Bool] BGS indicator for which BGS has not provided further documentation
    # @!attribute no_fiduciary_assigned_indicator
    #   @return [Bool] Returns true if the veteran has not been assigned a fiduciary
    # @!attribute not_deceased_indicator
    #   @return [Bool] Returns true if the veteran is still alive
    #
    class ControlInformation
      include Vets::Model

      attribute :can_update, Bool
      attribute :corp_avail_indicator, Bool
      attribute :corp_rec_found_indicator, Bool
      attribute :has_no_bdn_payments_indicator, Bool
      attribute :is_competent_indicator, Bool
      attribute :indentity_indicator, Bool
      attribute :index_indicator, Bool
      attribute :no_fiduciary_assigned_indicator, Bool
      attribute :not_deceased_indicator, Bool
    end
  end
end
