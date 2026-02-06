# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class PowerOfAttorneyRequestBlueprint < Blueprinter::Base
        view :shared_response do
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
                middle_name: request['vetMiddleName'],
                last_name: request['vetLastName']
              },
              claimant: {
                first_name: request['claimantFirstName'],
                last_name: request['claimantLastName']
              },
              address: {
                city: request['claimantCity'],
                state_code: request['claimantState'],
                zip_code: request['claimantZip'],
                countryCode: request['claimantCountry']
              },
              representative: {
                poa_code: request['poaCode']
              },
              received_date: request['dateRequestReceived'],
              actioned_date: request['dateRequestActioned'],
              status: request['secondaryStatus'],
              declined_reason: request['declinedReason'],
              consent_address_change: request['changeAddressAuth'] == 'Y',
              record_consent: request['healthInfoAuth'] == 'Y'
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
                  country_code: request.dig('veteran', 'address', 'countryCode'),
                  zip_code: request.dig('veteran', 'address', 'zipCode'),
                  zip_code_suffix: request.dig('veteran', 'address', 'zipCodeSuffix')
                },
                phone: {
                  country_code: request.dig('veteran', 'phone', 'countryCode'),
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
                  country_code: request.dig('claimant', 'address', 'countryCode'),
                  zip_code: request.dig('claimant', 'address', 'zipCode'),
                  zip_code_suffix: request.dig('claimant', 'address', 'zipCodeSuffix')
                },
                phone: {
                  country_code: request.dig('claimant', 'phone', 'countryCode'),
                  area_code: request.dig('claimant', 'phone', 'areaCode'),
                  phone_number: request.dig('claimant', 'phone', 'phoneNumber')
                },
                email: request.dig('claimant', 'email'),
                relationship: request.dig('claimant', 'relationship')
              },
              representative: {
                poa_code: request.dig('representative', 'poaCode')
              },
              record_consent: request['recordConsent'],
              consent_limits: request['consentLimits'],
              consent_address_change: request['consentAddressChange']
            }
          end

          transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
        end
        # rubocop:enable Naming/VariableNumber
      end
    end
  end
end
