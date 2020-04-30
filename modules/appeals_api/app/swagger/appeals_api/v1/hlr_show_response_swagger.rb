# frozen_string_literal: true

module AppealsApi
  module V1
    module HlrShowResponseSwagger
      include Swagger::Blocks

      def self.extended(base)
        base.response 404 do
          key :description, 'Info about a single Higher-Level Review'
          content 'application/json' do
            schema do
              property :data do
=begin
                property(:id) { key :"$ref", :Uuid }
                property :type do
                  key :type, 'string'
                  key :enum, ['HigherLevelReview']
                end
                property :attributes do
                  property(:status) { key :"$ref", :HlrStatus }
                  property(:updated_at) { key :"$ref", :TimeStamp }
                  property(:created_at) { key :"$ref", :TimeStamp }
                end
=end
              end
            end
          end
          key(
            :examples,
            {
              "HlrFound": {
                "value": {
                  "data": {
                    "id": '1234567a-89b0-123c-d456-789e01234f56',
                    "type": 'HigherLevelReview',
                    "attributes": {
                      "status": 'processed',
                      "updated_at": '2020-04-23T21:06:12.531Z',
                      "created_at": '2020-04-23T21:06:12.531Z'
                    }
                  }
                }
              }
            }
          )
        end
      end
    end
  end
end
