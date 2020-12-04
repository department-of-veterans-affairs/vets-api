# frozen_string_literal: true

module Swagger
  module Schemas
    module ContactUs
      class InquiriesList
        include Swagger::Blocks

        swagger_schema :InquiriesList do
          property :inquiries, type: :object do
            property :id, type: :string, example: nil
          end
        end
      end
    end
  end
end
