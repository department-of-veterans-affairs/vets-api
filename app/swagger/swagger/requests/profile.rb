# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
# rubocop:disable Layout/LineLength
module Swagger
  module Requests
    class Profile
      include Swagger::Blocks

      swagger_path '/v0/profile/direct_deposits/disability_compensations' do
        operation :get do
          key :produces, ['application/json']
          key :consumes, ['application/json']
          key :description, 'Get a veterans direct deposit information for compensation and pension benefits'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          response 200 do
            key :description, 'Direct deposit information for a users compensation and pension benefits.'
            schema do
              key :type, :object
              property(:data) do
                key :type, :object
                property :id, type: :string
                property :type, type: :string
                property :attributes do
                  key :type, :object

                  property :control_information do
                    key :required, %i[
                      can_update_direct_deposit
                      is_corp_available
                      is_corp_rec_found
                      has_no_bdn_payments
                      has_identity
                      has_index
                      is_competent
                      has_mailing_address
                      has_no_fiduciary_assigned
                      is_not_deceased
                      has_payment_address
                    ]
                    property :can_update_direct_deposit, type: :boolean, example: true, description: 'Must be true to view payment account information'
                    property :is_corp_available, type: :boolean, example: true, description: ''
                    property :is_corp_rec_found, type: :boolean, example: true, description: ''
                    property :has_no_bdn_payments, type: :boolean, example: true, description: ''
                    property :has_identity, type: :boolean, example: true, description: ''
                    property :has_index, type: :boolean, example: true, description: ''
                    property :is_competent, type: :boolean, example: true, description: ''
                    property :has_mailing_addres, type: :boolean, example: true, description: ''
                    property :has_no_fiduciary_assigne, type: :boolean, example: true, description: ''
                    property :is_not_decease, type: :boolean, example: true, description: ''
                    property :has_payment_address, type: :boolean, example: true, description: ''
                  end

                  property :payment_account do
                    key :required, %i[
                      name
                      account_type
                      account_number
                      routing_number
                    ]
                    property :name, type: :string, example: 'WELLS FARGO BANK', description: 'Bank name'
                    property :account_type, type: :string, enum: %w[CHECKING SAVINGS], example: 'CHECKING', description: 'Bank account type'
                    property :account_number, type: :string, example: '******7890', description: 'Bank account number (masked)'
                    property :routing_number, type: :string, example: '*****0503', description: 'Bank routing number (masked)'
                  end
                end
              end
            end
          end

          response 400 do
            key :description, ' Bad Request'
            schema do
              key :required, [:errors]

              property :errors do
                key :type, :array
                items do
                  key :required, %i[title detail code status source]
                  property :title, type: :string,
                                   example: 'Invalid field value',
                                   description: 'Error title'
                  property :detail, type: :string,
                                    example: 'getDirectDeposit.icn size must be between 17 and 17, getDirectDeposit.icn must match \"^\\d{10}V\\d{6}$\"',
                                    description: 'Description of error (optional)'
                  property :code, type: :string,
                                  example: 'LIGHTHOUSE_DIRECT_DEPOSIT400',
                                  description: 'Service name with code appended'
                  property :source, type: %i[string object],
                                    example: 'Lighthouse Direct Deposit',
                                    description: 'Service name'
                  property :status, type: :integer,
                                    example: 400,
                                    description: 'http status code'
                end
              end
            end
          end

          response 401 do
            key :description, 'Not authorized'
            schema do
              key :required, [:errors]

              property :errors do
                key :type, :array
                items do
                  key :required, %i[title detail code status source]
                  property :title, type: :string, example: 'Invalid token.', description: 'Error title'
                  property :detail, type: %i[string null], description: 'Description of error (optional)'
                  property :code, type: :string, example: 'LIGHTHOUSE_DIRECT_DEPOSIT401',
                                  description: 'Service name with code appended'
                  property :source, type: %i[string object], example: 'Lighthouse Direct Deposit',
                                    description: 'Service name'
                  property :status, type: :integer, example: 401, description: 'http status code'
                end
              end
            end
          end

          response 403 do
            key :description, 'Forbidden'
            schema do
              key :type, :object
              property(:data) do
                key :type, :object
                property :id, type: :string
                property :type, type: :string
                property :attributes do
                  key :type, :object

                  property :control_information do
                    key :required, %i[
                      can_update_direct_deposit
                      is_corp_available
                      is_corp_rec_found
                      has_no_bdn_payments
                      has_identity
                      has_index
                      is_competent
                      has_mailing_address
                      has_no_fiduciary_assigned
                      is_not_deceased
                      has_payment_address
                    ]
                    property :can_update_direct_deposit, type: :boolean, example: false, description: ''
                    property :is_corp_available, type: :boolean, example: false, description: ''
                    property :is_corp_rec_found, type: :boolean, example: false, description: ''
                    property :has_no_bdn_payments, type: :boolean, example: false, description: ''
                    property :has_identity, type: :boolean, example: false, description: ''
                    property :has_index, type: :boolean, example: false, description: ''
                    property :is_competent, type: :boolean, example: false, description: ''
                    property :has_mailing_addres, type: :boolean, example: false, description: ''
                    property :has_no_fiduciary_assigne, type: :boolean, example: false, description: ''
                    property :is_not_decease, type: :boolean, example: false, description: ''
                    property :has_payment_address, type: :boolean, example: false, description: ''
                  end

                  property :payment_account do
                    key :required, %i[
                      name
                      account_type
                      account_number
                      routing_number
                    ]
                    property :name, type: :string, example: 'WELLS FARGO BANK', description: 'Bank name'
                    property :account_type, type: :string, enum: %w[CHECKING SAVINGS], example: 'CHECKING', description: 'Bank account type'
                    property :account_number, type: :string, example: '******7890', description: 'Bank account number (masked)'
                    property :routing_number, type: :string, example: '*****0503', description: 'Bank routing number (masked)'
                  end
                end
              end
            end
          end

          response 404 do
            key :description, 'Not found'
            schema do
              key :required, [:errors]

              property :errors do
                key :type, :array
                items do
                  key :required, %i[title detail code status source]
                  property :title, type: :string, example: 'Person for ICN not found', description: 'Error title'
                  property :detail, type: :string, example: 'No data found for ICN', description: 'Description of error (optional)'
                  property :code, type: :string, example: 'LIGHTHOUSE_DIRECT_DEPOSIT404',
                                  description: 'Service name with code appended'
                  property :source, type: %i[string object], example: 'Lighthouse Direct Deposit',
                                    description: 'Service name'
                  property :status, type: :integer, example: 404, description: 'http status code'
                end
              end
            end
          end

          response 502 do
            key :description, 'Bad Gateway'
            schema do
              key :required, [:errors]

              property :errors do
                key :type, :array
                items do
                  key :required, %i[title detail code status source]
                  property :title, type: :string, example: 'Required Backend Connection Error', description: 'Error title'
                  property :detail, type: :string, example: 'e9e04329-b211-11ed-9449-732003342465', description: 'Description of error (optional)'
                  property :code, type: :string, example: 'LIGHTHOUSE_DIRECT_DEPOSIT502',
                                  description: 'Service name with code appended'
                  property :source, type: %i[string object], example: 'Lighthouse Direct Deposit',
                                    description: 'Service name'
                  property :status, type: :integer, example: 502, description: 'http status code'
                end
              end
            end
          end
        end

        operation :put do
          key :produces, ['application/json']
          key :consumes, ['application/json']
          key :description, 'Update a veterans direct deposit information for compensation and pension benefits'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes to update a payment account.'
            key :required, true

            schema do
              property :account_number, type: :string, example: '1234567890'
              property :account_type, type: :string, example: 'Checking'
              property :routing_number, type: :string, example: '031000503'
            end
          end

          response 200 do
            key :description, 'Direct deposit information for a users compensation and pension benefits.'
            schema do
              key :type, :object
              property(:data) do
                key :type, :object
                property :id, type: :string
                property :type, type: :string
                property :attributes do
                  key :type, :object

                  property :control_information do
                    key :required, %i[
                      can_update_direct_deposit
                      is_corp_available
                      is_corp_rec_found
                      has_no_bdn_payments
                      has_identity
                      has_index
                      is_competent
                      has_mailing_address
                      has_no_fiduciary_assigned
                      is_not_deceased
                      has_payment_address
                    ]
                    property :can_update_direct_deposit, type: :boolean, example: true, description: 'Must be true to view payment account information'
                    property :is_corp_available, type: :boolean, example: true, description: ''
                    property :is_corp_rec_found, type: :boolean, example: true, description: ''
                    property :has_no_bdn_payments, type: :boolean, example: true, description: ''
                    property :has_identity, type: :boolean, example: true, description: ''
                    property :has_index, type: :boolean, example: true, description: ''
                    property :is_competent, type: :boolean, example: true, description: ''
                    property :has_mailing_addres, type: :boolean, example: true, description: ''
                    property :has_no_fiduciary_assigne, type: :boolean, example: true, description: ''
                    property :is_not_decease, type: :boolean, example: true, description: ''
                    property :has_payment_address, type: :boolean, example: true, description: ''
                  end

                  property :payment_account do
                    key :required, %i[
                      name
                      account_type
                      account_number
                      routing_number
                    ]
                    property :name, type: :string, example: 'WELLS FARGO BANK', description: 'Bank name'
                    property :account_type, type: :string, enum: %w[CHECKING SAVINGS], example: 'CHECKING', description: 'Bank account type'
                    property :account_number, type: :string, example: '******7890', description: 'Bank account number (masked)'
                    property :routing_number, type: :string, example: '*****0503', description: 'Bank routing number (masked)'
                  end
                end
              end
            end
          end

          response 400 do
            key :description, 'Routing number related to fraud'
            schema do
              key :required, [:errors]

              property :errors do
                key :type, :array
                items do
                  key :required, %i[title detail code status source]
                  property :title, type: :string, example: 'Bad Request', description: 'Error title'
                  property :detail, type: :string, example: 'Routing number related to potential fraud', description: 'Description of error (optional)'
                  property :code, type: :string, example: 'cnp.payment.routing.number.fraud.message', description: 'Service name with code appended'
                  property :source, type: %i[string object], example: 'Lighthouse Direct Deposit', description: 'Service name'
                  property :status, type: :integer, example: 400, description: 'http status code'
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/profile/communication_preferences/{communication_permission_id}' do
        operation :patch do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Update a communication permission'
          key :operationId, 'updateCommunicationPreference'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          key :produces, ['application/json']
          key :consumes, ['application/json']

          extend Swagger::Schemas::Vet360::CommunicationPermission
        end
      end

      swagger_path '/v0/profile/communication_preferences' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Create a communication permission'
          key :operationId, 'createCommunicationPreference'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          key :produces, ['application/json']
          key :consumes, ['application/json']

          extend Swagger::Schemas::Vet360::CommunicationPermission
        end

        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, "Get user's communication preferences data"
          key :operationId, 'getCommunicationPreferences'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          key :produces, ['application/json']
          key :consumes, ['application/json']

          response 200 do
            key :description, 'Communication preferences data'

            schema do
              key :type, :object

              property(:data) do
                key :type, :object

                property :id, type: :string
                property :type, type: :string

                property :attributes do
                  key :type, :object

                  property :communication_groups do
                    key :type, :array

                    items do
                      key :type, :object

                      property :id, type: :integer
                      property :name, type: :string
                      property :description, type: :string

                      property :communication_items do
                        key :type, :array

                        items do
                          key :type, :object

                          property :id, type: :integer
                          property :name, type: :string

                          property :communication_channels do
                            key :type, :array

                            items do
                              property :id, type: :integer
                              property :name, type: :string
                              property :description, type: :string
                              property :default_send_indicator, type: :boolean

                              property :communication_permission do
                                key :type, :object

                                property :id, type: :integer
                                property :allowed, type: :boolean
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/profile/ch33_bank_accounts' do
        operation :put do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Updates chapter 33 direct deposit bank info'
          key :operationId, 'updateCh33BankAccount'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          key :produces, ['application/json']
          key :consumes, ['application/json']

          parameter do
            key :name, :bank_account
            key :in, :body
            key :description, 'Bank account details'
            key :required, true

            schema do
              key :type, :object
              key :required, %i[account_type account_number financial_institution_routing_number]

              property :account_type, type: :string, enum: %w[Checking Savings]
              property :account_number, type: :string
              property :financial_institution_routing_number, type: :string
              property :ga_client_id, type: :string
            end
          end

          extend Swagger::Responses::Ch33BankAccountInfo

          response 400 do
            key :description, 'Update bank account error'
            schema do
              key :type, :object

              property(:update_ch33_dd_eft_response) do
                key :type, :object

                property '@xmlns:ns0', type: :string

                property :return do
                  key :type, :object

                  property :return_code, type: :string
                  property :return_message, type: :string
                end
              end
            end
          end
        end

        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets chapter 33 direct deposit bank info'
          key :operationId, 'getCh33BankAccount'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          key :produces, ['application/json']
          key :consumes, ['application/json']

          extend Swagger::Responses::Ch33BankAccountInfo
        end
      end

      swagger_path '/v0/profile/address_validation' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Outputs address suggestions'
          key :operationId, 'postVet360AddressValidation'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          key :produces, ['application/json']
          key :consumes, ['application/json']

          parameter do
            key :name, :address
            key :in, :body
            key :description, 'Address input'
            key :required, true

            schema do
              key :type, :object
              key :required, [:address]

              property(:address) do
                key :$ref, :Vet360AddressSuggestion
                key :required, %i[
                  address_pou
                ]
              end
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :type, :object
              property(:validation_key, type: :integer)

              property(:addresses) do
                key :type, :array

                items do
                  key :type, :object

                  property(:address) do
                    key :$ref, :Vet360AddressSuggestion
                  end

                  property(:address_meta_data) do
                    key :type, :object

                    property(:confidence_score, type: :number)
                    property(:address_type, type: :string)
                    property(:delivery_point_validation, type: :string)
                    property(:residential_delivery_indicator, type: :string)
                  end
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/profile/addresses/create_or_update' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, "Create or updates a user's VA profile address"
          key :operationId, 'changeVaProfileAddress'
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
              key :$ref, :PostVet360DomesticAddress
            end
          end

          parameter do
            key :name, :international_body
            key :in, :body
            key :description, 'Attributes to create an international address.'
            key :required, true

            schema do
              key :$ref, :PostVet360InternationalAddress
            end
          end

          parameter do
            key :name, :military_overseas_body
            key :in, :body
            key :description, 'Attributes to create a military overseas address.'
            key :required, true

            schema do
              key :$ref, :PostVet360MilitaryOverseasAddress
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
            end
          end
        end
      end

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
              key :$ref, :PostVet360DomesticAddress
            end
          end

          parameter do
            key :name, :international_body
            key :in, :body
            key :description, 'Attributes to create an international address.'
            key :required, true

            schema do
              key :$ref, :PostVet360InternationalAddress
            end
          end

          parameter do
            key :name, :military_overseas_body
            key :in, :body
            key :description, 'Attributes to create a military overseas address.'
            key :required, true

            schema do
              key :$ref, :PostVet360MilitaryOverseasAddress
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
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
              key :$ref, :PutVet360DomesticAddress
            end
          end

          parameter do
            key :name, :international_body
            key :in, :body
            key :description, 'Attributes to update an international address.'
            key :required, true

            schema do
              key :$ref, :PutVet360InternationalAddress
            end
          end

          parameter do
            key :name, :military_overseas_body
            key :in, :body
            key :description, 'Attributes to update a military overseas address.'
            key :required, true

            schema do
              key :$ref, :PutVet360MilitaryOverseasAddress
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
            end
          end
        end

        operation :delete do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Logically deletes a user\'s existing Vet360 address'
          key :operationId, 'deleteVet360Address'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :domestic_body
            key :in, :body
            key :description, 'Attributes of the domestic address.'
            key :required, true

            schema do
              key :$ref, :PutVet360DomesticAddress
            end
          end

          parameter do
            key :name, :international_body
            key :in, :body
            key :description, 'Attributes of the international address.'
            key :required, true

            schema do
              key :$ref, :PutVet360InternationalAddress
            end
          end

          parameter do
            key :name, :military_overseas_body
            key :in, :body
            key :description, 'Attributes of the military overseas address.'
            key :required, true

            schema do
              key :$ref, :PutVet360MilitaryOverseasAddress
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
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
              key :$ref, :PhoneNumber
            end
          end

          response 403 do
            key :description, 'Forbidden'
            schema do
              key :$ref, :EVSSAuthError
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
              key :$ref, :PhoneNumber
            end
          end

          response 403 do
            key :description, 'Forbidden'
            schema do
              key :$ref, :EVSSAuthError
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
              key :$ref, :Email
            end
          end

          response 403 do
            key :description, 'Forbidden'
            schema do
              key :$ref, :EVSSAuthError
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
              key :$ref, :Email
            end
          end

          response 403 do
            key :description, 'Forbidden'
            schema do
              key :$ref, :EVSSAuthError
            end
          end
        end
      end

      swagger_path '/v0/profile/email_addresses/create_or_update' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Create or update a users VA profile email address'
          key :operationId, 'changeVaProfileEmailAddress'
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
              key :$ref, :PostVet360Email
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
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
              key :$ref, :PostVet360Email
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
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
              key :$ref, :PutVet360Email
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
            end
          end
        end

        operation :delete do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Deletes a users existing Vet360 email address'
          key :operationId, 'deleteVet360EmailAddress'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes of an email address.'
            key :required, true

            schema do
              key :$ref, :PutVet360Email
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
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

      swagger_path '/v0/profile/initialize_vet360_id' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Initializes a vet360_id for the current user'
          key :operationId, 'initializeVet360Id'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
            end
          end
        end
      end

      swagger_path '/v0/profile/person/status/{transaction_id}' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets an updated person transaction by ID'
          key :operationId, 'getPersonTransactionStatusById'
          key :tags, %w[profile]

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
              key :$ref, :AsyncTransactionVet360
            end
          end
        end
      end

      swagger_path '/v0/profile/personal_information' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets a users gender, birth date, preferred name, and gender identity'
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
                  property :preferred_name, type: :string, example: 'Pat'
                  property :gender_identity, type: :object do
                    property :code, type: :string, example: 'F'
                    property :name, type: :string, example: 'Female'
                  end
                end
              end
            end
          end

          response 502 do
            key :description, 'Unexpected response body'
            schema do
              key :required, [:errors]

              property :errors do
                key :type, :array
                items do
                  key :required, %i[title detail code status source]
                  property :title, type: :string, example: 'Unexpected response body'
                  property :detail,
                           type: :string,
                           example: 'MVI service responded without a birthday or a gender.'
                  property :code, type: :string, example: 'MVI_BD502'
                  property :status, type: :string, example: '502'
                  property :source, type: :string, example: 'V0::Profile::PersonalInformationsController'
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
              key :$ref, :PhoneNumber
            end
          end

          response 403 do
            key :description, 'Forbidden'
            schema do
              key :$ref, :EVSSAuthError
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
              key :$ref, :PhoneNumber
            end
          end

          response 403 do
            key :description, 'Forbidden'
            schema do
              key :$ref, :EVSSAuthError
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
                      property :service_type, type: :string, example: 'Military Service'
                      property :branch_of_service, type: :string, example: 'Air Force'
                      property :begin_date, type: :string, format: :date, example: '2007-04-01'
                      property :end_date, type: :string, format: :date, example: '2016-06-01'
                      property :termination_reason_code, type: :string, example: 'S', description: 'S = Separation From Personnel Category, C = Completion of Active Service Period, D = Death while in personnel category or organization, W = Not Applicable'
                      property :termination_reason_text, type: :string, example: 'Separation from personnel category or organization'
                      property :personnel_category_type_code, type: :string, example: 'V', description: 'A = Regular Active, N = Guard, V = Reserve, Q = Reserve Retiree'
                    end
                  end
                end
              end
            end
          end

          response 400 do
            key :description, '_CUF_UNEXPECTED_ERROR'
            schema do
              key :required, [:errors]

              property :errors do
                key :type, :array
                items do
                  key :required, %i[title detail code status source]
                  property :title, type: :string, example: '_CUF_UNEXPECTED_ERROR'
                  property :detail,
                           type: :string,
                           example: 'there was an error encountered processing the Request.  Please retry.  If problem persists, please contact support with a copy of the Response.'
                  property :code, type: :string, example: 'CORE100'
                  property :status, type: :string, example: '400'
                  property :source, type: :string, example: 'V0::Profile::ServiceHistoriesController'
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
          key :tags, %w[profile]

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
              key :$ref, :AsyncTransactionVet360
            end
          end
        end
      end

      swagger_path '/v0/profile/status/' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Gets the most recent transactions for a user.'\
                            ' Response will include an array of transactions that are still in progress,'\
                            ' or that were just updated to COMPLETED during the course of this request.'\
                            ' The array will be empty if no transactions are pending or updated.'\
                            ' Only the most recent transaction for each profile field will be included'\
                            ' so there may be up to 4 (Address, Email, Telephone, Permission).'
          key :operationId, 'getTransactionStatusesByUser'
          key :tags, %w[profile]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionsVet360
            end
          end
        end
      end

      swagger_path '/v0/profile/telephones/create_or_update' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Create or update a users VA profile telephone'
          key :operationId, 'changeVaProfileTelephone'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes to create a telephone.'
            key :required, true

            schema do
              key :$ref, :PostVet360Telephone
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
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
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes to create a telephone.'
            key :required, true

            schema do
              key :$ref, :PostVet360Telephone
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
            end
          end
        end

        operation :put do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Updates a users existing telephone'
          key :operationId, 'putVet360Telephone'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes to update a telephone'
            key :required, true

            schema do
              key :$ref, :PutVet360Telephone
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
            end
          end
        end

        operation :delete do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Deletes an existing telephone'
          key :operationId, 'deleteVet360Telephone'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes of a telephone'
            key :required, true

            schema do
              key :$ref, :PutVet360Telephone
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
            end
          end
        end
      end

      swagger_path '/v0/profile/permissions/create_or_update' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Create or update a users VA profile permission'
          key :operationId, 'changeVet360Permission'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes to create a permission.'
            key :required, true

            schema do
              key :$ref, :PostVet360Permission
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
            end
          end
        end
      end

      swagger_path '/v0/profile/permissions' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Creates a users Vet360 permission'
          key :operationId, 'postVet360Permission'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes to create a permission.'
            key :required, true

            schema do
              key :$ref, :PostVet360Permission
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
            end
          end
        end

        operation :put do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Updates a users existing permission'
          key :operationId, 'putVet360Permission'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes to update a permission'
            key :required, true

            schema do
              key :$ref, :PutVet360Permission
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
            end
          end
        end

        operation :delete do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Deletes an existing permission'
          key :operationId, 'deleteVet360Permission'
          key :tags, %w[
            profile
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes of a permission'
            key :required, true

            schema do
              key :$ref, :PutVet360Permission
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :AsyncTransactionVet360
            end
          end
        end
      end

      swagger_path '/v0/profile/connected_applications' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'GET OAuth Applications'
          key :operationId, 'getConnectedApplications'
          key :tags, ['profile']

          parameter :authorization

          response 200 do
            key :description, 'List of OAuth applications you have connected'
            schema do
              key :$ref, :ConnectedApplications
            end
          end
        end
      end
      swagger_path '/v0/profile/connected_applications/{application_id}' do
        operation :delete do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Delete grants for OAuth Applications'
          key :operationId, 'deleteConnectedApplications'
          key :tags, ['profile']

          parameter :authorization

          parameter do
            key :name, :application_id
            key :in, :path
            key :description, 'ID of application'
            key :required, true
            key :type, :string
          end

          response 204, description: "the connected application's grant have been deleted"
        end
      end

      swagger_path '/v0/profile/valid_va_file_number' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'GET returns true false if veteran has a VA file number'
          key :operationId, 'getValidVAFileNumber'
          key :tags, ['profile']

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :ValidVAFileNumber
            end
          end
        end
      end

      swagger_path '/v0/profile/payment_history' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'GET returns two arrays. One is payments made, the other is payments returned'
          key :operationId, 'getPaymentHistory'
          key :tags, ['profile']

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :PaymentHistory
            end
          end
        end
      end

      swagger_path '/v0/profile/preferred_names' do
        operation :put do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Adds or updates a users preferred name'
          key :operationId, 'putPreferredName'
          key :tags, ['profile']

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes to update a users preferred name'
            key :required, false

            schema do
              key :$ref, :PutPreferredName
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :PreferredName
            end
          end
        end
      end

      swagger_path '/v0/profile/gender_identities' do
        operation :put do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Adds or updates a users gender identity'
          key :operationId, 'putGenderIdentity'
          key :tags, ['profile']

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Attributes to update a users gender identity'
            key :required, false

            schema do
              key :$ref, :PutGenderIdentity
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :GenderIdentity
            end
          end
        end
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
# rubocop:enable Layout/LineLength
