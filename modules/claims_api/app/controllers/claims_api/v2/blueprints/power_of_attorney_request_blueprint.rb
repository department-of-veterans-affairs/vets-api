# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class PowerOfAttorneyRequestBlueprint < Blueprinter::Base
        view :index_or_show do
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
              actioned_date: request['dateRequestActioned'],
              status: request['secondaryStatus'],
              declined_reason: request['declinedReason'],
              change_address_authorization: request['changeAddressAuth'],
              health_info_authorization: request['healthInfoAuth']
            }
          end

          transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
        end

        # rubocop:disable Naming/VariableNumber
        view :create do
          field :id do |request|
            request['id']
          end

          field :type do
            'power-of-attorney-request'
          end

          field :attributes do |request|
            {
              veteran: {
                service_number: request.dig('veteran', 'serviceNumber'),
                service_branch: request.dig('veteran', 'serviceBranch'),
                address: {
                  address_line_1: request.dig('veteran', 'address', 'addressLine1'),
                  address_line_2: request.dig('veteran', 'address', 'addressLine2'),
                  city: request.dig('veteran', 'address', 'city'),
                  state_code: request.dig('veteran', 'address', 'stateCode'),
                  country: request.dig('veteran', 'address', 'country'),
                  zip_code: request.dig('veteran', 'address', 'zipCode'),
                  zip_code_suffix: request.dig('veteran', 'address', 'zipCodeSuffix')
                },
                phone: {
                  area_code: request.dig('veteran', 'phone', 'areaCode'),
                  phone_number: request.dig('veteran', 'phone', 'phoneNumber')
                },
                email: request.dig('veteran', 'email'),
                insurance_number: request.dig('veteran', 'insuranceNumber')
              },
              claimant: {
                claimant_id: request.dig('claimant', 'claimantId'),
                address: {
                  address_line_1: request.dig('claimant', 'address', 'addressLine1'),
                  address_line_2: request.dig('claimant', 'address', 'addressLine2'),
                  city: request.dig('claimant', 'address', 'city'),
                  state_code: request.dig('claimant', 'address', 'stateCode'),
                  country: request.dig('claimant', 'address', 'country'),
                  zip_code: request.dig('claimant', 'address', 'zipCode'),
                  zip_code_suffix: request.dig('claimant', 'address', 'zipCodeSuffix')
                },
                phone: {
                  area_code: request.dig('claimant', 'phone', 'areaCode'),
                  phone_number: request.dig('claimant', 'phone', 'phoneNumber')
                },
                email: request.dig('claimant', 'email'),
                relationship: request.dig('claimant', 'relationship')
              },
              poa: {
                poa_code: request.dig('poa', 'poaCode'),
                registration_number: request.dig('poa', 'registrationNumber'),
                job_title: request.dig('poa', 'jobTitle')
              },
              record_consent: request['recordConsent'],
              consent_limits: request['consentLimits'],
              consent_address_change: request['consentAddressChange']
            }
          end

          transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
        end
        # rubocop:enable Naming/VariableNumber

        view :decide do
          field :id do |res|
            res['id']
          end

          field :type do
            'power-of-attorney-request-decision'
          end

          field :attributes do |res|
            res.except('id')
          end

          transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
        end
      end
    end
  end
end
