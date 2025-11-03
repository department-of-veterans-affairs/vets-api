module Lighthouse
  module HCC
    class ChargeItem
      include Vets::Model
      attribute :service_description, String
      attribute :provider, Array # we might use encounter here, we'll see. This seems like it shold be a string instad of an array but 'note' returns array
      attribute :date, String # datetime?
      attribute :late_fee_description, String
      # attribute :billing_ref_id, String #int?  String commenting for now, seems in invoice
      # attribute :billing_reference,            String commenting for now, seems in invoice
      attribute :date_posted, String # datetime?
      attribute :description, String


      def initialize(params)
        @params = params
        assign_attributes
      end

      def assign_attributes
        @service_description = @params['resource']['code']['text']
        @provider = @params.dig('resource', 'note')&.map { |n| n["text"] } # maybe we use encounter instead
        @date = @params['resource']['occurrenceDateTime']
        @late_fee_description = @params['resource']['code']['text'] # seems like possible nil error at text?
        @date_posted = @params['resource']['enteredDate'] # datetime?
        @description = @late_fee_description
      end
    end
  end
end
