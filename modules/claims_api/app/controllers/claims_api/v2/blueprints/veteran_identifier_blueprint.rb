# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class VeteranIdentifierBlueprint < Blueprinter::Base
        identifier :id do |entity, _options|
          entity.mpi.icn
        end

        transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
      end
    end
  end
end
