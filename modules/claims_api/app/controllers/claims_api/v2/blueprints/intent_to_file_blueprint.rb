# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class IntentToFileBlueprint < Blueprinter::Base
        identifier :id
        field :creation_date
        field :expiration_date
        field :status
        field :type

        transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
      end
    end
  end
end
