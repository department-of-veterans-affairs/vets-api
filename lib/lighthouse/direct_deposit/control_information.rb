# frozen_string_literal: true

module Lighthouse
  module DirectDeposit
    class ControlInformation
      include ActiveModel::Model

      attr_accessor :can_update_direct_deposit,
                    :is_corp_available,
                    :is_corp_rec_found,
                    :has_no_bdn_payments,
                    :has_identity,
                    :has_index,
                    :is_competent,
                    :has_mailing_address,
                    :has_no_fiduciary_assigned,
                    :is_not_deceased,
                    :has_payment_address
    end
  end
end
