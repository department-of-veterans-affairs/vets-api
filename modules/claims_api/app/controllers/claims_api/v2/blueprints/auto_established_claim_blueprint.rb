# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class AutoEstablishedClaimBlueprint < Blueprinter::Base
        identifier :id
        field :type do |_options|
          'forms/526'
        end

        field :attributes do |claim, _options|
          claim&.form_data
        end
      end
    end
  end
end
