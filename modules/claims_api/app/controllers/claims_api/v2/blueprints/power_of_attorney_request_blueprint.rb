# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class PowerOfAttorneyRequestBlueprint < Blueprinter::Base
        view :index do
          field :id do |request|
            request['id']
          end

          field :type do
            'power-of-attorney-request'
          end

          field :attributes do |request|
            {
              veteran: {
                first_name: request['vetFirstName'],
                last_name: request['vetLastName'],
                middle_name: request['vetMiddleName']
              },
              claimant: {
                city: request['claimantCity'],
                country: request['claimantCountry'],
                military_po: request['claimantMilitaryPO'],
                military_postal_code: request['claimantMilitaryPostalCode'],
                state: request['claimantState'],
                zip: request['claimantZip']
              },
              representative: {
                poa_code: request['poaCode'],
                vso_user_email: request['VSOUserEmail'],
                vso_user_first_name: request['VSOUserFirstName'],
                vso_user_last_name: request['VSOUserLastName']
              },
              received_date: request['dateRequestReceived'],
              decision_date: request['dateRequestActioned'],
              status: request['secondaryStatus'],
              declined_reason: request['declinedReason'],
              change_address_authorization: request['changeAddressAuth'],
              health_info_authorization: request['healthInfoAuth']
            }
          end

          transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
        end

        view :create do
          field :id do |request|
            request['id']
          end

          field :type do
            'power-of-attorney-request'
          end

          field :attributes do |request|
            request.except('id')
          end

          transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
        end
      end
    end
  end
end
