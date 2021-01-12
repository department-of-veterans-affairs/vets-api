# frozen_string_literal: true

module Swagger
  module Responses
    module Ch33BankAccountInfo
      def self.extended(base)
        base.response 200 do
          key :description, 'Chapter 33 Bank account details'

          schema do
            key :type, :object

            property(:data) do
              key :type, :object
              property :id, type: :string
              property :type, type: :string

              property :attributes do
                key :type, :object

                property :account_type, type: :string
                property :account_number, type: :string
                property :financial_institution_name, type: :string
                property :financial_institution_routing_number, type: :string
              end
            end
          end
        end
      end
    end
  end
end
