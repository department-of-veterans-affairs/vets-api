# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class ClaimBlueprint < Blueprinter::Base
        identifier :id
        field :type

        transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
      end
    end
  end
end
