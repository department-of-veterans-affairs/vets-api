# frozen_string_literal: true

require 'decision_reviews/v1/constants'
require 'decision_reviews/v1/logging_utils'

module DecisionReviews
  module V1
    module Helpers
      # Included in https://github.com/department-of-veterans-affairs/vets-api/pull/13973/files
      # for backwards compatibility. We may consider keeping these modules completely separate
      # in the future.
      include DecisionReviews::V1::LoggingUtils

      DR_LOCKBOX = Lockbox.new(key: Settings.lockbox.master_key, encode: true)

      def middle_initial(user)
        user.middle_name.to_s.strip.presence&.first&.upcase
      end

      # Takes original payload (or anything that responds to to_json)
      # Then encrypts it so that there is no PII in the sidekiq args
      def payload_encrypted_string(payload)
        DR_LOCKBOX.encrypt(payload.to_json)
      end

      def get_and_rejigger_required_info(request_body:, form4142:, user:)
        data = request_body['data']
        attrs = data['attributes']
        vet = attrs['veteran']
        x = {
          vaFileNumber: user.ssn.to_s.strip.presence,
          veteranSocialSecurityNumber: user.ssn.to_s.strip.presence,
          veteranFullName: {
            first: user.first_name.to_s,
            middle: middle_initial(user),
            last: user.last_name.to_s.presence
          },
          veteranDateOfBirth: user.birth_date.to_s.strip.presence,
          veteranAddress: transform_address_fields(vet['address']),
          email: vet['email'],
          veteranPhone: "#{vet['phone']['areaCode']}#{vet['phone']['phoneNumber']}"
        }
        x.merge(form4142).deep_stringify_keys
      end

      def transform_address_fields(address)
        address.merge(
          {
            'street' => address['addressLine1'],
            'street2' => address['addressLine2'],
            'state' => address['stateCode'],
            'country' => IsoCountryCodes.find(address['countryCodeISO2'])&.alpha3,
            'postalCode' => address['zipCode5']
          }
        )
      end

      def create_supplemental_claims_headers(user)
        headers = {
          'X-VA-SSN' => user.ssn.to_s.strip.presence,
          'X-VA-ICN' => user.icn.presence,
          'X-VA-First-Name' => user.first_name.to_s.strip.first(12),
          'X-VA-Middle-Initial' => middle_initial(user),
          'X-VA-Last-Name' => user.last_name.to_s.strip.first(18).presence,
          'X-VA-Birth-Date' => user.birth_date.to_s.strip.presence
        }.compact

        missing_required_fields = SC_REQUIRED_CREATE_HEADERS - headers.keys
        if missing_required_fields.present?
          e = Common::Exceptions::Forbidden.new(
            source: "#{self.class}##{__method__}",
            detail: { missing_required_fields: }
          )
          raise e
        end

        headers
      end
    end
  end
end
