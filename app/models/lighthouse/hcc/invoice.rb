module Lighthouse
  module HCC
    class Invoice
      include Vets::Model
      attribute :facility, String
      attribute :current_balance, String
      attribute :billing_ref, Array
      attribute :amount, String
      attribute :previous_balance, String
      attribute :previous_unpaid_balance, String
      attribute :url, String
      attribute :external_id, String

      def initialize(params)
        @params = params
        assign_attributes
      end

      def assign_attributes
        @facility = @params["resource"]["issuer"]["display"]
        @current_balance = @params["resource"]["totalPriceComponent"].map { |tpc| tpc["amount"]["value"] }.sum
        # Seems like we need to maybe make a collection for latest charges where this attribute is mentioned in the mapping doc we made
        # We are just ripping this code for now
        @billing_ref = @params["resource"]["lineItem"].map { |li| li["chargeItemReference"]["reference"].split("/").last }
        @amount = @params["resource"]["totalPriceComponent"].map do |tpc|
          next if tpc["type"] == "informational"
          tpc["amount"]["value"]
        end.compact.sum
        # Maybe we need to pass the index and get the previous amount from the last invoice?
        @previous_balance = @params["resource"]["totalPriceComponent"].find { |component| component["type"] == "informational" }["amount"]["value"]
        @previous_unpaid_balance = @params["resource"]["totalPriceComponent"].find { |component| component["type"] == "informational" }["amount"]["value"]
        @url = @params["resource"]["fullUrl"]
        @external_id = @params["resource"]["id"]
      end
    end
  end
end
