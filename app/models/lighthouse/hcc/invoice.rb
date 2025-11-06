# frozen_string_literal: true

module Lighthouse
  module HCC
    class Invoice
      include Vets::Model
      attribute :id, String
      attribute :external_id, String
      attribute :facility, String
      attribute :billing_ref, Array
      attribute :current_balance, Float
      attribute :previous_balance, String
      attribute :previous_unpaid_balance, String
      attribute :url, String

      def initialize(params)
        @params = params
        assign_attributes
      end

      def assign_attributes
        @id = @params['resource']['id']
        @facility = @params['resource']['issuer']['display']
        # Seems like we need to maybe make a collection for latest charges where this
        # attribute is mentioned in the mapping doc we made
        # We are just ripping this code for now
        @billing_ref = @params['resource']['lineItem'].map do |li|
          li['chargeItemReference']['reference'].split('/').last
        end
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
