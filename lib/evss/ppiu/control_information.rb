# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module PPIU
    class ControlInformation
      include Virtus.model

      attribute :can_update_address, Boolean
      attribute :corp_avail_indicator, Boolean
      attribute :corp_rec_found_indicator, Boolean
      attribute :has_no_bdn_payments_indicator, Boolean
      attribute :is_competent_indicator, Boolean
      attribute :identity_indicator, Boolean
      attribute :index_indicator, Boolean
      attribute :no_fiduciary_assigned_indicator, Boolean
      attribute :not_deceased_indicator, Boolean
    end
  end
end
