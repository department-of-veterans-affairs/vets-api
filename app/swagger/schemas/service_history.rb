# frozen_string_literal: true

module Swagger
  module Schemas
    class ServiceHistory
      include Swagger::Blocks

      swagger_schema :ServiceHistory do
        key :required, [:data]

        property :data, type: :object do
          key :required, [:attributes]
          property :attributes, type: :object do
            key :required, [:service_history]
            property :service_history do
              key :type, :array
              items do
                key :required, %i[branch_of_service begin_date]
                property :branch_of_service, type: :string, example: 'Air Force'
                property :begin_date, type: :string, example: '2007-04-01'
                property :end_date, type: :string, example: '2016-06-01'
              end
            end
          end
        end
      end
    end
  end
end
