# frozen_string_literal: true

module Swagger
  module Schemas
    module ContactUs
      class InquiriesList
        include Swagger::Blocks

        swagger_schema :InquiriesList do
          property :inquiries, type: :array do
            items do
              key :$ref, :InquirySummary
            end
          end
        end

        swagger_schema :InquirySummary do
          property :subject, type: :string, example: 'Prosthetics'
          property :confirmationNumber, type: :string, example: '000-010'
          property :status, type: :string, example: 'OPEN'
          property :creationTimestamp, type: :string, example: '2020-11-01T14:58:00+01:00'
          property :lastActiveTimestamp, type: :string, example: '2020-11-04T13:00:00+01:00'
          property :links, type: :object do
            property :thread, type: :object do
              property :href, type: :string
            end
          end
        end
      end
    end
  end
end
