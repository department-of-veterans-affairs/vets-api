# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class PaymentInformation < Common::Resource
      attribute :id, Types::String
      attribute :account_control do
        attribute :can_update_address, Types::Bool
        attribute :corp_avail_indicator, Types::Bool
        attribute :corp_rec_found_indicator, Types::Bool
        attribute :has_no_bdn_payments_indicator, Types::Bool
        attribute :identity_indicator, Types::Bool
        attribute :is_competent_indicator, Types::Bool
        attribute :index_indicator, Types::Bool
        attribute :no_fiduciary_assigned_indicator, Types::Bool
        attribute :not_deceased_indicator, Types::Bool
        attribute :can_update_payment, Types::Bool
      end
      attribute :payment_account do
        attribute :account_type, Types::String
        attribute :financial_institution_name, Types::String
        attribute :account_number, Types::String
        attribute :financial_institution_routing_number, Types::String
      end

      def self.create_from_upstream(record, user_uuid)
        record = record.to_h.transform_values(&:to_h)
        record[:id] = user_uuid
        record[:account_control] = record.delete(:control_information)
        record[:payment_account][:account_number] = StringHelpers.mask_sensitive(record[:payment_account][:account_number])
        new(record)
      end

      def self.legacy_create_from_upstream(record, user_uuid)
        prepared_record = { id: user_uuid, account_control: record.control_information.to_h, payment_account: record.payment_account.to_h }
        prepared_record[:account_control][:can_update_payment] = record.control_information.authorized?
        prepared_record[:payment_account][:account_number] = StringHelpers.mask_sensitive(prepared_record[:payment_account][:account_number])
        new(prepared_record)
      end
    end
  end
end
