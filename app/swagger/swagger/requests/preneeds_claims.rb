# frozen_string_literal: true

module Swagger
  module Requests
    class PreneedsClaims
      include Swagger::Blocks

      swagger_schema :PreneedAddress do
        property :street, type: :string, example: '140 Rock Creek Church Rd NW'
        property :street2, type: :string, example: ''
        property :city, type: :string, example: 'Washington'
        property :country, type: :string, example: 'USA'
        property :state, type: :string, example: 'DC'
        property :postalCode, type: :string, example: '20011'
      end

      swagger_schema :PreneedName do
        property :first, type: :string, example: 'Jon'
        property :middle, type: :string, example: 'Bob'
        property :last, type: :string, example: 'Doe'
        property :suffix, type: :string, example: 'Jr.'
        property :maiden, type: :string, example: 'Smith'
      end

      swagger_path '/v0/preneeds/burial_forms' do
        operation :post do
          extend Swagger::Responses::ValidationError

          key :description, 'Submit a pre-need burial eligibility claim'
          key :operationId, 'addPreneedsClaim'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :application
            key :in, :body
            key :description, 'Pre-need burial eligibility form data'
            key :required, true

            schema do
              key :required, %i[applicant claimant hasCurrentlyBuried veteran]
              property :applicationStatus, type: :string, example: 'example needed' # TODO: not in schema.  remove?
              property :hasCurrentlyBuried, type: :string, example: '1', enum: %w[1 2 3]
              property :sendingCode, type: :string, example: 'abc' # TODO: not in schema.  remove?
              property :currentlyBuriedPersons, type: :array, description: 'data about claimants' do
                items do
                  property :name, type: :object do
                    key :'$ref', :PreneedName
                  end
                  property :cemeteryNumber, type: :string, example: '234'
                end
              end
              property :preneedAttachments, type: :array, description: 'data about uploaded attachments' do
                items do
                  property :confirmationCode, type: :string, description: 'uuid',
                                              example: '9b3ae0e1-fd58-4074-bf81-d58fb18fa86'
                  property :attachmentId, type: :string, example: '1'
                  property :name, type: :string, example: 'my_file_name.pdf'
                end
              end
              property :applicant, type: :object do
                property :applicantEmail, type: :string, example: 'jon.doe@example.com'
                property :applicantPhoneNumber, type: :string, example: '5551235454'
                property :applicantRelationshipToClaimant, type: :string, example: 'Authorized Agent/Rep'
                property :completingReason, type: :string, example: 'a reason'
                property :mailingAddress, type: :object do
                  key :'$ref', :PreneedAddress
                end
                property :name, type: :object do
                  key :'$ref', :PreneedName
                end
              end
              property :claimant, type: :object do
                property :address, type: :object do
                  key :'$ref', :PreneedAddress
                end
                property :dateOfBirth, type: :string, example: '1960-12-30'
                property :desiredCemetery, type: :string, example: '234'
                property :email, type: :string, example: 'jon.doe@example.com'
                property :name, type: :object do
                  key :'$ref', :PreneedName
                end
                property :phoneNumber, type: :string, example: '5551235454'
                property :relationshipToVet, type: :string, example: '2'
                property :ssn, type: :string, example: '234234234'
              end
              property :veteran, type: :object do
                property :address, type: :object do
                  key :'$ref', :PreneedAddress
                end
                property :currentName, type: :object do
                  key :'$ref', :PreneedName
                end
                property :dateOfBirth, type: :string, example: '1960-12-30'
                property :dateOfDeath, type: :string, example: '1990-12-30'
                property :gender, type: :string, example: 'Female'
                property :isDeceased, type: :string, example: 'yes'
                property :maritalStatus, type: :string, example: 'Single'
                property :militaryServiceNumber, type: :string, example: '234234234'
                property :militaryStatus, type: :string, example: 'D'
                property :placeOfBirth, type: :string, example: '140 Rock Creek Church Rd NW'
                property :serviceName, type: :object do
                  key :'$ref', :PreneedName
                end

                property :race, type: :object, description: 'veteran ethnicities' do
                  property :isAmericanIndianOrAlaskanNative, type: :boolean
                  property :isAsian, type: :boolean
                  property :isBlackOrAfricanAmerican, type: :boolean
                  property :isSpanishHispanicLatino, type: :boolean
                  property :notSpanishHispanicLatino, type: :boolean
                  property :isNativeHawaiianOrOtherPacificIslander, type: :boolean
                  property :isWhite, type: :boolean
                end

                property :serviceRecords, type: :array, description: 'data about tours of duty' do
                  items do
                    property :dateRange, type: :object do
                      property :from, type: :string, example: '1960-12-30'
                      property :to, type: :string, example: '1970-12-30'
                    end
                    property :serviceBranch, type: :string, example: 'AL'
                    property :dischargeType, type: :string, example: '2'
                    property :highestRank, type: :string, example: 'General'
                    property :nationalGuardState, type: :string, example: 'PR'
                  end
                end
                property :ssn, type: :string, example: '234234234'
                property :vaClaimNumber, type: :string, example: '234234234'
              end
            end
          end

          response 200 do
            key :description, 'Application was submitted successfully'
            schema do
              key :required, [:data]
              property :data, type: :object do
                key :required, %i[attributes id type]
                property :id, type: :string, example: 'MQP6Tmqi44S1y5wEWGVG'
                property :type, type: :string, example: 'preneeds_receive_applications'
                property :attributes, type: :object do
                  property :receive_application_id, type: :string, example: 'MQP6Tmqi44S1y5wEWGVG'
                  property :tracking_number, type: :string, example: 'MQP6Tmqi44S1y5wEWGVG'
                  property :return_code, type: :integer, example: 0
                  property :application_uuid, type: :string, example: '8da5eb1a-26b4-48e3-99ca-089453472df7'
                  property :return_description, type: :string, example: 'PreNeed Application Received Successfully.'
                  property :submitted_at, type: :string, example: '2018-10-29T14:28:46.201Z'
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/preneeds/preneed_attachments' do
        operation :post do
          extend Swagger::Responses::BadRequestError
          extend Swagger::Responses::UnprocessableEntityError

          key :description, 'Upload a pdf or image file'
          key :operationId, 'addPreneedsAttachments'
          key :tags, %w[benefits_forms]

          parameter do
            key :name, :preneed_attachments
            key :in, :body
            key :description, 'Object containing file name'
            key :required, true

            schema do
              key :required, %i[file_data]
              property :file_data, type: :string, example: 'filename.pdf'
              property :password, type: :string, example: 'My Password'
            end
          end

          response 200 do
            key :description, 'Response is ok'
            schema do
              key :'$ref', :UploadSupportingEvidence
            end
          end
        end
      end
    end
  end
end
