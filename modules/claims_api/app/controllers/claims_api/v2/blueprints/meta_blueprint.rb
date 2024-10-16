# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class MetaBlueprint < Blueprinter::Base
        association :data, blueprint: AutoEstablishedClaimBlueprint do |claim, _options|
          claim
        end

        field :meta, if: ->(_field_name, claim, _options) { claim.transaction_id.present? } do |claim, _options|
          { transactionId: claim.transaction_id }
        end
      end
    end
  end
end
