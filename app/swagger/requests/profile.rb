# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
module Swagger
  module Requests
    class Profile
      include Swagger::Blocks

      swagger_path '/v0/profile/addresses' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Creates a users Vet360 address'
          key :operationId, 'postVet360Address'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :domestic_body
            key :in, :body
            key :description, 'Attributes to create a domestic address.'
            key :required, true

            schema do
              key :'$ref', :PostVet360DomesticAddress
            end
          end

          parameter do
            key :name, :international_body
            key :in, :body
            key :description, 'Attributes to create an international address.'
            key :required, true

            schema do
              key :'$ref', :PostVet360InternationalAddress
            end
          end

          parameter do
            key :name, :military_overseas_body
            key :in, :body
            key :description, 'Attributes to create a military overseas address.'
            key :required, true

            schema do
              key :'$ref', :PostVet360MilitaryOverseasAddress
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :AsyncTransactionVet360
            end
          end
        end

        operation :put do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Updates a users existing Vet360 address'
          key :operationId, 'putVet360Address'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :domestic_body
            key :in, :body
            key :description, 'Attributes to update a domestic address.'
            key :required, true

            schema do
              key :'$ref', :PutVet360DomesticAddress
            end
          end

          parameter do
            key :name, :international_body
            key :in, :body
            key :description, 'Attributes to update an international address.'
            key :required, true

            schema do
              key :'$ref', :PutVet360InternationalAddress
            end
          end

          parameter do
            key :name, :military_overseas_body
            key :in, :body
            key :description, 'Attributes to update a military overseas address.'
            key :required, true

            schema do
              key :'$ref', :PutVet360MilitaryOverseasAddress
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :AsyncTransactionVet360
            end
          end
        end
      end

      swagger_path '/v0/profile/alternate_phone' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets a users alternate phone number information'
          key :operationId, 'getAlternatePhone'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :PhoneNumber
            end
          end
        end

        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Creates/updates a users alternate phone number information'
          key :operationId, 'postAlternatePhone'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes to create/update a phone number.'
            key :required, true

            schema do
              property :number, type: :string, example: '4445551212'
              property :extension, type: :string, example: '101'
              property :country_code, type: :string, example: '1'
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :PhoneNumber
            end
          end
        end
      end

      swagger_path '/v0/profile/email' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets a users email address information'
          key :operationId, 'getEmailAddress'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Email
            end
          end
        end

        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Creates/updates a users email address'
          key :operationId, 'postEmailAddress'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes to create/update an email address.'
            key :required, true

            schema do
              property :email, type: :string, example: 'john@example.com'
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Email
            end
          end
        end
      end

      swagger_path '/v0/profile/email_addresses' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Creates a users Vet360 email address'
          key :operationId, 'postVet360EmailAddress'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes to create an email address.'
            key :required, true

            schema do
              key :'$ref', :PostVet360Email
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :AsyncTransactionVet360
            end
          end
        end

        operation :put do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Updates a users existing Vet360 email address'
          key :operationId, 'putVet360EmailAddress'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes to update an email address.'
            key :required, true

            schema do
              key :'$ref', :PutVet360Email
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :AsyncTransactionVet360
            end
          end
        end
      end

      swagger_path '/v0/profile/full_name' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets a users full name with suffix'
          key :operationId, 'getFullName'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :required, [:data]

              property :data, type: :object do
                key :required, [:attributes]
                property :attributes, type: :object do
                  property :first, type: :string, example: 'Jack'
                  property :middle, type: :string, example: 'Robert'
                  property :last, type: :string, example: 'Smith'
                  property :suffix, type: :string, example: 'Jr.'
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/profile/personal_information' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets a users gender and birth date'
          key :operationId, 'getPersonalInformation'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :required, [:data]

              property :data, type: :object do
                key :required, [:attributes]
                property :attributes, type: :object do
                  property :gender, type: :string, example: 'M'
                  property :birth_date, type: :string, format: :date, example: '1949-03-04'
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/profile/primary_phone' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets a users primary phone number information'
          key :operationId, 'getPrimaryPhone'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :PhoneNumber
            end
          end
        end

        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Creates/updates a users primary phone number information'
          key :operationId, 'postPrimaryPhone'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes to create/update a phone number.'
            key :required, true

            schema do
              property :number, type: :string, example: '4445551212'
              property :extension, type: :string, example: '101'
              property :country_code, type: :string, example: '1'
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :PhoneNumber
            end
          end
        end
      end

      swagger_path '/v0/profile/service_history' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets a collection of a users military service episodes'
          key :operationId, 'getServiceHistory'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
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
                      property :begin_date, type: :string, format: :date, example: '2007-04-01'
                      property :end_date, type: :string, format: :date, example: '2016-06-01'
                    end
                  end
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/profile/status/{transaction_id}' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets an updated transaction by ID'
          key :operationId, 'getTransactionStatusById'
          key :tags, %w[profile vet360]

          parameter :authorization
          parameter do
            key :name, :transaction_id
            key :in, :path
            key :description, 'ID of transaction'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :AsyncTransactionVet360
            end
          end
        end
      end

      swagger_path '/v0/profile/status/' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets the most recent transactions for a user.
            Response will include transactions that are still in progress,
            or just updated to COMPLETED during the course of this request.'
          key :operationId, 'getTransactionStatusesByUser'
          key :tags, %w[profile vet360]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :AsyncTransactionVet360
            end
          end
        end
      end

      swagger_path '/v0/profile/telephones' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Creates a users Vet360 telephone'
          key :operationId, 'postVet360Telephone'
          key :tags, %w[
            profile
            vet360
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes to create a telephone.'
            key :required, true

            schema do
              key :'$ref', :PostVet360Telephone
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :AsyncTransactionVet360
            end
          end
        end

        operation :put do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Updates a users existing telephone'
          key :operationId, 'putVet360Telephone'
          key :tags, %w[
            profile
            vet360
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes to update a telephone'
            key :required, true

            schema do
              key :'$ref', :PutVet360Telephone
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :AsyncTransactionVet360
            end
          end
        end
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
