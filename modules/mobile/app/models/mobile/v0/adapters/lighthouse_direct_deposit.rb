# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class LighthouseDirectDeposit
        def parse(direct_deposit_info)
          JSON.parse({
            control_information: parse_control_information(direct_deposit_info.control_information),
            payment_account: parse_payment_account(direct_deposit_info.payment_account)
          }.to_json,
                     object_class: OpenStruct)
        end

        private

        def parse_control_information(account_control_info)
          {
            can_update_address: account_control_info['can_update_direct_deposit'],
            corp_avail_indicator: account_control_info['is_corp_available'],
            corp_rec_found_indicator: account_control_info['is_corp_rec_found'],
            has_no_bdn_payments_indicator: account_control_info['has_no_bdn_payments'],
            identity_indicator: account_control_info['has_identity'],
            is_competent_indicator: account_control_info['is_competent'],
            index_indicator: account_control_info['has_index'],
            no_fiduciary_assigned_indicator: account_control_info['has_no_fiduciary_assigned'],
            not_deceased_indicator: account_control_info['is_not_deceased'],
            can_update_payment: account_control_info['can_update_direct_deposit']
          }
        end

        def parse_payment_account(payment_account_info)
          {
            account_type: payment_account_info[:account_type],
            financial_institution_name: payment_account_info[:name],
            account_number: payment_account_info[:account_number],
            financial_institution_routing_number: payment_account_info[:routing_number]
          }
        end
      end
    end
  end
end
