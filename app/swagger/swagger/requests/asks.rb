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
          key :tags, %w[contact_us]

          parameter :optional_authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'The properties to create a get help inquiry'
            key :required, true

            schema do
              property :inquiry do
                property :form do
                  key :required, %i[
                    inquiryType
                    query
                    preferredContactMethod
                  ]
                  property :topic do
                    key :required, %i[
                      levelOne
                      levelTwo
                    ]
                    property :levelOne,
                             type: :string,
                             example: 'Health & Medical Issues & Services'
                    property :levelTwo,
                             type: :string,
                             example: 'Prosthetics, Med Devices & Sensory Aids'
                    property :levelThree,
                             type: :string,
                             example: 'Eyeglasses'
                    property :vaMedicalCenter,
                             type: :string,
                             example: '405GC'
                  end
                  property :inquiryType,
                           type: :string,
                           example: 'Question'
                  property :query,
                           type: :string,
                           example: 'Can you please help me?'
                  property :veteranStatus do
                    key :required, %i[
                      veteranStatus
                    ]
                    property :veteranStatus,
                             type: :string,
                             example: 'dependent'
                    property :isDependent,
                             type: :boolean,
                             example: false
                    property :relationshipToVeteran,
                             type: :string,
                             example: 'Attorney'
                    property :veteranIsDeceased,
                             type: :boolean,
                             example: false
                    property :branchOfService,
                             type: :string,
                             example: 'Air Force'
                  end
                  property :veteranInformation do
                    property :first,
                             type: :string,
                             example: 'Darth'
                    property :last,
                             type: :string,
                             example: 'Vader'
                    property :address do
                      property :street,
                               type: :string,
                               example: '123 Main St'
                      property :street2,
                               type: :string,
                               example: 'Apt 3'
                      property :city,
                               type: :string,
                               example: 'Chicago'
                      property :country,
                               type: :string,
                               example: 'USA'
                      property :state,
                               type: :string,
                               example: 'IL'
                      property :postalCode,
                               type: :string,
                               example: '60601'
                    end
                    property :email,
                             type: :string,
                             example: 'callmyagent@stormtroopers.com'
                    property :phone,
                             type: :string,
                             example: '8003334567'
                  end
                  property :dependentInformation do
                    property :first,
                             type: :string,
                             example: 'Luke'
                    property :last,
                             type: :string,
                             example: 'Skywalker'
                    property :address do
                      property :street,
                               type: :string,
                               example: '123 Main St'
                      property :street2,
                               type: :string,
                               example: 'Apt 2'
                      property :city,
                               type: :string,
                               example: 'Chicago'
                      property :country,
                               type: :string,
                               example: 'USA'
                      property :state,
                               type: :string,
                               example: 'IL'
                      property :postalCode,
                               type: :string,
                               example: '60601'
                    end
                    property :email,
                             type: :string,
                             example: 'luke.skywalker@jediacademy.edu'
                    property :phone,
                             type: :string,
                             example: '8007651234'
                  end
                  property :veteranServiceInformation do
                    property :dateOfBirth,
                             type: :string,
                             example: '1957-03-07'
                    property :socialSecurityNumber,
                             type: :string,
                             example: '222113333'
                    property :serviceNumber,
                             type: :string,
                             example: '123456789001'
                    property :claimNumber,
                             type: :string,
                             example: '12345678'
                    property :serviceDateRange do
                      property :from,
                               type: :string,
                               example: '1973-02-16'
                      property :to,
                               type: :string,
                               example: '1976-05-07'
                    end
                  end
                  property :fullName do
                    key :required, %i[
                      first
                      last
                    ]
                    property :first,
                             type: :string,
                             example: 'Obi Wan'
                    property :last,
                             type: :string,
                             example: 'Kenobi'
                    property :suffix,
                             type: :string,
                             example: 'IV'
                  end
                  property :preferredContactMethod,
                           type: :string,
                           example: 'email'
                  property :email,
                           type: :string,
                           example: 'obi1kenobi@gmail.com'
                  property :phone,
                           type: :string,
                           example: '8001234567'
                  property :address do
                    key :required, %i[
                      country
                    ]
                    property :street,
                             type: :string,
                             example: '123 Main St'
                    property :street2,
                             type: :string,
                             example: 'Apt 1'
                    property :city,
                             type: :string,
                             example: 'Chicago'
                    property :country,
                             type: :string,
                             example: 'USA'
                    property :state,
                             type: :string,
                             example: 'IL'
                    property :postalCode,
                             type: :string,
                             example: '60601'
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

          response 501 do
            key :description, 'Feature toggled off'
          end
        end
      end
    end
  end
end
