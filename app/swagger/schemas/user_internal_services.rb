# frozen_string_literal: true

module Swagger
  module Schemas
    class UserInternalServices
      include Swagger::Blocks

      swagger_schema :UserInternalServices do
        property :data, type: :object do
          property :id, type: :string
          property :type, type: :string
          property :attributes, type: :object do
            property :services, type: :array do
              key :example, %w[gibs facilities hca edu-benefits evss-claims appeals-status user-profile id-card
                               identity-proofed vet360 rx messaging health-records mhv-accounts
                               form-save-in-progress form-prefill]
              items do
                key :type, :string
              end
            end
            property :in_progress_forms do
              key :type, :array
              items do
                property :form, type: :string
                property :metadata, type: :object do
                  property :version, type: :integer
                  property :return_url, type: :string
                  property :expires_at, type: :integer
                  property :last_updated, type: :integer
                end
                property :last_updated, type: :integer
              end
            end
            property :account, type: :object do
              property :account_uuid,
                       type: %w[string null],
                       example: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef',
                       description: 'A UUID correlating all user identifiers. Intended to become the user\'s UUID.'
            end
            property :profile, type: :object do
              property :email, type: :string
              property :first_name, type: :string
              property :last_name, type: :string
              property :birth_date, type: :string
              property :gender, type: :string
              property :zip, type: :string
              property :last_signed_in, type: :string
              property :sign_in, type: :object do
                property :service_name, type: :string
              end
              property :loa, type: :object do
                property :current, type: :integer, format: :int32
                property :highest, type: :integer, format: :int32
              end
            end
            property :prefills_available do
              key :type, :array
              items do
                key :type, :string
              end
            end
          end
        end
      end
    end
  end
end
