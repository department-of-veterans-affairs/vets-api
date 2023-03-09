# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class IntentToFileBlueprint < Blueprinter::Base
        identifier :id

        field :type do |_itf, _options|
          'intent_to_file'
        end

        field :attributes do |itf, _options|
          {
            creation_date: itf[:creation_date],
            expiration_date: itf[:expiration_date],
            type: ClaimsApi::V2::IntentToFile::ITF_TYPES_TO_BGS_TYPES.key(itf[:type]),
            status: itf[:status].downcase
          }
        end

        transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
      end
    end
  end
end
