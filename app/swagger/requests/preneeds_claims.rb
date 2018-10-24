# frozen_string_literal: true

module Swagger
  module Requests
    class PreneedsClaims
      include Swagger::Blocks

      swagger_path '/v0/preneeds/burial_forms' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm

          key :description, 'Submit a pre-need burial eligibility claim'
          key :operationId, 'addPreneedsClaim'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :application
            key :in, :body
            key :description, 'Pre-need burial eligibility form data'
            key :required, true

            # TODO: add `required` designations

            schema do
              property :applicationStatus, type: :string, example: 'example needed' # TODO: not in schema.  remove?
              property :hasCurrentlyBuried, type: :string, example: '1', enum: %w[1 2 3]
              property :sendingCode, type: :string, example: 'abc' # TODO: not in schema.  remove?
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
                property :mailingAddress, type: :object do
                  property :street, type: :string, example: '140 Rock Creek Church Rd NW'
                  property :street2, type: :string, example: ''
                  property :city, type: :string, example: 'Washington'
                  property :country, type: :string, example: 'USA'
                  property :state, type: :string, example: 'DC'
                  property :postalCode, type: :string, example: '20011'
                end
              end
            end
          end
        end
      end
    end
  end
end

# TODO
# permitted params from burial_forms_controller
# :application_status, :has_currently_buried, :sending_code,
#           preneed_attachments: ::Preneeds::PreneedAttachmentHash.permitted_params,
#           applicant: ::Preneeds::Applicant.permitted_params,
#           claimant: ::Preneeds::Claimant.permitted_params,
#           currently_buried_persons: ::Preneeds::CurrentlyBuriedPerson.permitted_params,
#           veteran: ::Preneeds::Veteran.permitted_params
