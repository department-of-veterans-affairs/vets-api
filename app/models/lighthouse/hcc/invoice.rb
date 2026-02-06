# frozen_string_literal: true

module Lighthouse
  module HCC
    class Invoice
      include Vets::Model
      attribute :external_id, String
      attribute :facility, String
      attribute :facility_id, String
      attribute :city, String
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
        line_item = @params.dig('resource', 'lineItem')&.first
        @facility = @params.dig('resource', 'issuer', 'display')
        @facility_id = @params.dig('resource', 'facility_id')
        @city = @params.dig('resource', 'city')
        @latest_billing_ref = line_item
                              &.dig('chargeItemReference', 'reference')
                              &.split('/')
                              &.last
        @last_credit_debit = line_item&.dig('priceComponent', 0, 'amount', 'value')

        @last_updated_at = @params.dig('resource', 'meta', 'lastUpdated')

        @current_balance = calculate_current_balance ? calculate_current_balance.compact.sum : 0.0
        @previous_balance = @params['resource']['totalPriceComponent'].find do |c|
          c['type'] == 'informational' && c.dig('code', 'text') == 'Original Amount'
        end&.dig('amount', 'value')&.to_f

        @previous_unpaid_balance = @params['resource']['totalPriceComponent']
                                   .select { |c| %w[base surcharge].include?(c['type']) }
                                   .sum { |c| c.dig('amount', 'value').to_f }

        @url = @params.dig('resource', 'fullUrl')
        @external_id = @params.dig('resource', 'id')
      end

      def calculate_current_balance
        @params.dig('resource', 'totalPriceComponent')&.map do |tpc|
          next if tpc['type'] == 'informational'

          tpc['amount']['value']
        end
      end
    end
  end
end
