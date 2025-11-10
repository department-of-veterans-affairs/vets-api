# frozen_string_literal: true

module Lighthouse
  module HCC
    class Invoice
      include Vets::Model
      attribute :external_id, String
      attribute :facility, String
      attribute :latest_billing_ref, String
      attribute :current_balance, Float
      attribute :previous_balance, String
      attribute :previous_unpaid_balance, String
      attribute :last_updated_at, String
      attribute :last_credit_debit, Float
      attribute :url, String

      def initialize(params)
        @params = params
        assign_attributes
      end

      def assign_attributes
        @facility = @params['resource']['issuer']['display']
        @latest_billing_ref = @params['resource']['lineItem'].first['chargeItemReference']['reference'].split('/').last
        @last_updated_at = @params['resource']['meta']['lastUpdated']
        @last_credit_debit = @params['resource']['lineItem'].first['priceComponent'].first['amount']['value']
        @current_balance = @params['resource']['totalPriceComponent'].map do |tpc|
          next if tpc['type'] == 'informational'

          tpc['amount']['value']
        end.compact.sum
        # Maybe we need to pass the index and get the previous amount from the last invoice?
        @previous_balance = @params['resource']['totalPriceComponent'].find do |component|
          component['type'] == 'informational'
        end['amount']['value']

        @previous_unpaid_balance = @params['resource']['totalPriceComponent'].find do |component|
          component['type'] == 'informational'
        end['amount']['value']

        @url = @params['resource']['fullUrl']
        @external_id = @params['resource']['id']
      end
    end
  end
end
