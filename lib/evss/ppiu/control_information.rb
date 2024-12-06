# frozen_string_literal: true

require 'vets/model'

module EVSS
  module PPIU
    class ControlInformation
      include Vets::Model
      ##
      # Determines if the user can update their address.
      # Updates are only allowed when all member variables of this object are 'true'
      #
      # @!attribute can_update_address
      #   @return [Bool] Global flag indicating if the user can update their address.
      #   All other variables in this object must be true for this to be true.
      # @!attribute corp_avail_indicator
      #   @return [Bool] BGS indicator for which BGS has not provided further documentation
      # @!attribute corp_rec_found_indicator
      #   @return [Bool] BGS indicator for which BGS has not provided further documentation
      # @!attribute has_no_bdn_payments_indicator
      #   @return [Bool] Returns true unless the veteran has received BDN payments
      # @!attribute identity_indicator
      #   @return [Bool] BGS indicator for which BGS has not provided further documentation
      # @!attribute is_competent_indicator
      #   @return [Bool] Returns true if the veteran has not been deemed legally incompetent
      # @!attribute index_indicator
      #   @return [Bool] BGS indicator for which BGS has not provided further documentation
      # @!attribute no_fiduciary_assigned_indicator
      #   @return [Bool] Returns true if the veteran has not been assigned a fiduciary
      # @!attribute not_deceased_indicator
      #   @return [Bool] Returns true if the veteran is still alive
      #
      attribute :can_update_address, Bool, default: false
      attribute :corp_avail_indicator, Bool, default: false
      attribute :corp_rec_found_indicator, Bool, default: false
      attribute :has_no_bdn_payments_indicator, Bool, default: false
      attribute :identity_indicator, Bool, default: false
      attribute :is_competent_indicator, Bool, default: false
      attribute :index_indicator, Bool, default: false
      attribute :no_fiduciary_assigned_indicator, Bool, default: false
      attribute :not_deceased_indicator, Bool, default: false

      # This is used to map the misspelling we get from EVSS
      # to the correct spelling of "identity"
      def initialize(attrs)
        attrs['identity_indicator'] = attrs['indentity_indicator']
        super
      end

      def authorized?
        is_competent_indicator && no_fiduciary_assigned_indicator && not_deceased_indicator
      end
    end
  end
end
