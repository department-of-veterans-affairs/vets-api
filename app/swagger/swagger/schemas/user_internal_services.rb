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
            property :profile, type: :object do
              property :email, type: :string
              property :first_name, type: :string, example: 'Abigail'
              property :middle_name, type: :string, example: 'Jane'
              property :last_name, type: :string, example: 'Brown'
              property :preferred_name, type: %i[string null], example: 'Abby'
              property :birth_date, type: :string, example: '1900-01-01'
              property :gender, type: :string, example: 'F'
              property :zip,
                       type: %i[string null],
                       description: "The user's zip code from MPI"
              property :multifactor,
                       type: :boolean,
                       example: true,
                       description: "ID.me boolean value if the signed-in 'wallet' has multifactor enabled"
              property :last_signed_in, type: :string, example: '2019-10-02T13:55:54.261Z'
              property :initial_sign_in, type: :string, example: '2019-10-02T13:55:54.261Z'
              property :authn_context,
                       enum: ['dslogon', 'dslogon_loa3', 'dslogon_multifactor', 'myhealthevet', 'myhealthevet_loa3',
                              'myhealthevet_multifactor', LOA::IDME_LOA1_VETS, LOA::IDME_LOA3_VETS],
                       example: 'myhealthevet_loa3',
                       description: 'The login method of a user.
                                     If a user logs in using a DS Logon Username and password and then goes through
                                     identity verification with id.me their login type would be dslogon_loa3.
                                     or if they logged in with dslogon and added multifactor authentication through
                                     id.me their authn_context would be dslogon_multifactor'
              property :sign_in, type: :object do
                property :service_name,
                         type: :string,
                         enum: %w[mhv dslogon idme logingov],
                         example: 'mhv',
                         description: 'The name of the service that the user used for the beginning of the
                                       authentication process (username + password)'
                property :account_type,
                         enum: %w[Basic Premium 1 2 3],
                         example: 'Basic',
                         description: 'myhealthevet account_types: Basic, Premium. dslogon account account_types: 1-3'
                property :ssoe,
                         type: :boolean,
                         description: 'true if the user was authenticated using SSOe'
                property :transactionid,
                         type: :string,
                         example: 'E35imPCwyUBl/Eo4AhlCJfioOcQEWDdyjFXUJRBky1k=',
                         description: 'a unique id representing the authentication transaction with SSOe'
              end
              property :verified, type: :boolean, example: true
              property :loa, type: :object do
                property :current,
                         type: :integer,
                         format: :int32,
                         example: 3,
                         description: 'NIST level of assurance, either 1 or 3'
                property :highest,
                         type: :integer,
                         format: :int32,
                         example: 3,
                         description: "level of assurance - During the login flow reference 'highest', otherwise, use
                                       'current'"
              end
            end
            property :onboarding, type: :object do
              property :show,
                       type: :boolean,
                       description: 'Whether the client should display Veteran Onboarding information'
            end
            property :prefills_available do
              key :type, :array
              items do
                key :type, :string
              end
            end
            property :session, type: :object do
              property :ssoe, type: :boolean
              property :transactionid, type: %i[string null]
            end
          end
        end
      end
    end
  end
end
