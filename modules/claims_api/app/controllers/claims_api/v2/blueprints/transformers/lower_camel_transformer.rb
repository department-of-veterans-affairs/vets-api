# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      module Transformers
        class LowerCamelTransformer < Blueprinter::Transformer
          def transform(hash, _object, _options)
            hash.deep_transform_keys! { |key| key.to_s.camelize(:lower).to_sym }
          end
        end
      end
    end
  end
end
