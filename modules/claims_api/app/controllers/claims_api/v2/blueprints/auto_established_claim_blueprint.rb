# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class AutoEstablishedClaimBlueprint < Blueprinter::Base
        identifier :id
        field :type do |_options|
          'forms/526'
        end

        field :attributes do |claim, options|
          if options[:async] == false
            { claimId: claim&.evss_id&.to_s }.merge(claim&.form_data)
          else
            claim&.form_data
          end
        end

        # field :meta, if: ->(_field_name, claim, options) { claim.transaction_id != nil } do |claim, options|
        #   { transaction_id: claim.transaction_id}
        # end
      end
    end
  end
end
