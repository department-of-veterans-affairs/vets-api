# frozen_string_literal: true

module Swagger
  module Requests
    class Asks
      include Swagger::Blocks

      swagger_path '/v0/ask/asks' do
        operation :post do
          extend Swagger::Responses::ValidationError

          key :description, 'Submit a message'
          key :operationId, 'createsAnInquiry'
          key :tags, %w[get_help_ask_form]

          parameter :optional_authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'The properties to create a get help inquiry'
            key :required, true

            schema do
              property :inquiry do
                property :form do
                  property :topic do
                    property :levelOne,
                             type: :string,
                             example: 'Caregiver Support Program'
                    property :levelTwo,
                             type: :string,
                             example: 'VA Supportive Services'
                  end
                  property :inquiryType,
                           type: :string,
                           example: 'Question'
                  property :query,
                           type: :string,
                           example: 'Can you please help me?'
                  property :veteranStatus do
                    property :veteranStatus,
                             type: :string,
                             example: 'general'
                  end
                  property :fullName do
                    property :first,
                             type: :string,
                             example: 'Obi Wan'
                    property :last,
                             type: :string,
                             example: 'Kenobi'
                  end
                  property :preferredContactMethod,
                           type: :string,
                           example: 'email'
                  property :email,
                           type: :string,
                           example: 'obi1kenobi@gmail.com'
                  property :address do
                    property :country,
                             type: :string,
                             example: 'USA'
                  end
                end
              end
            end
          end

          response 201 do
            key :description, 'Successful inquiry creation'
            schema do
              key :'$ref', :Asks
            end
          end
        end
      end
    end
  end
end
