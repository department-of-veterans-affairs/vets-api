# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module PPIU
    ##  # TODO - see if we can remove
    # Determines if the user can update their address.
    # Updates are only allowed when all member variables of this object are 'true'
    #
    # @!attribute can_update_address
    #   @return [Boolean] Global flag indicating if the user can update their address.
    #   All other variables in this object must be true for this to be true.
    # @!attribute corp_avail_indicator
    #   @return [Boolean] BGS indicator for which BGS has not provided further documentation
    # @!attribute corp_rec_found_indicator
    #   @return [Boolean] BGS indicator for which BGS has not provided further documentation
    # @!attribute has_no_bdn_payments_indicator
    #   @return [Boolean] Returns true unless the veteran has received BDN payments
    # @!attribute identity_indicator
    #   @return [Boolean] BGS indicator for which BGS has not provided further documentation
    # @!attribute is_competent_indicator
    #   @return [Boolean] Returns true if the veteran has not been deemed legally incompetent
    # @!attribute index_indicator
    #   @return [Boolean] BGS indicator for which BGS has not provided further documentation
    # @!attribute no_fiduciary_assigned_indicator
    #   @return [Boolean] Returns true if the veteran has not been assigned a fiduciary
    # @!attribute not_deceased_indicator
    #   @return [Boolean] Returns true if the veteran is still alive
    #
    class ControlInformation
      include Virtus.model

      attribute :can_update_address, Boolean
      attribute :corp_avail_indicator, Boolean
      attribute :corp_rec_found_indicator, Boolean
      attribute :has_no_bdn_payments_indicator, Boolean
      attribute :identity_indicator, Boolean
      attribute :is_competent_indicator, Boolean
      attribute :index_indicator, Boolean
      attribute :no_fiduciary_assigned_indicator, Boolean
      attribute :not_deceased_indicator, Boolean

      # This is used to map the misspelling we get from EVSS
      # to the correct spelling of "identity"
      def initialize(attrs)
        super(attrs)
        self.identity_indicator = attrs['indentity_indicator']
      end

      def authorized?
        is_competent_indicator &&
          no_fiduciary_assigned_indicator &&
          not_deceased_indicator
      end
    end
  end
end
