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

      def format_phone_number(phone)
        return {} if phone.blank?

        country_code = phone['countryCode'] || ''
        area_code = phone['areaCode'] || ''
        number = phone['phoneNumber']

        if country_code == '1' || country_code.blank?
          { veteranPhone: "#{area_code}#{number}" }
        else
          { internationalPhoneNumber: "+#{country_code} #{area_code}#{number}" }
        end
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
          email: vet['email']
        }

        x.merge!(format_phone_number(vet['phone'])).compact!

        transformed_form4142 = transform_form4142_data(form4142)
        x.merge(transformed_form4142).deep_stringify_keys
      end

      def transform_form4142_data(form4142_data)
        return form4142_data unless form4142_data.is_a?(Hash)

        transformed_data = form4142_data.deep_dup

        if transformed_data['providerFacility'].is_a?(Array)
          transformed_data['providerFacility'].each do |facility|
            # Convert the 'issues' array received from the FE to a 'conditionsTreated' string
            # as expected by the backend schema
            facility['conditionsTreated'] = facility.delete('issues') if facility.is_a?(Hash) && facility.key?('issues')
            if facility['conditionsTreated'].is_a?(Array)
              facility['conditionsTreated'] = facility['conditionsTreated'].join(', ')
            end
          end
        end

        transformed_data
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

      def normalize_area_code_for_lighthouse_schema(req_body_obj)
        phone = req_body_obj.dig('data', 'attributes', 'veteran', 'phone')
        area_code = phone&.dig('areaCode')

        return req_body_obj if area_code.is_a?(String) && !area_code.empty?

        phone_hash = req_body_obj.dig('data', 'attributes', 'veteran', 'phone')
        phone_hash.delete('areaCode') if phone_hash.is_a?(Hash)
        req_body_obj
      end

      def validate_and_format_va_treatment_date(date_string)
        return nil unless date_string.match?(/^\d{4}-\d{2}$/)

        "#{date_string}-01"
      end

      def format_va_evidence_entries(va_evidence)
        return if va_evidence.blank?

        va_evidence.map do |entry|
          formatted_entry = {
            'type' => 'retrievalEvidence',
            'attributes' => {}
          }

          evidence_entry = entry.dup
          formatted_entry['attributes']['locationAndName'] = evidence_entry['vaTreatmentLocation']

          has_treatment_before_2005 = evidence_entry['treatmentBefore2005'] == 'Y'

          if has_treatment_before_2005
            treatment_date = validate_and_format_va_treatment_date(evidence_entry['treatmentMonthYear'].to_s)

            if treatment_date
              formatted_entry['attributes']['evidenceDates'] = [{
                'startDate' => treatment_date,
                'endDate' => treatment_date
              }]
            end
          end

          formatted_entry['attributes']['noTreatmentDates'] =
            !has_treatment_before_2005 || treatment_date.nil?

          formatted_entry
        end
      end

      def make_issues_list(issues_hash)
        issues_hash.select { |_key, value| value == true }.keys
      end

      def format_private_evidence_entries(private_evidence)
        return if private_evidence.blank?

        authorization = private_evidence['auth4142']
        limited_consent_prompt = private_evidence['lcPrompt']
        limited_consent_details = private_evidence['lcDetails']
        evidence_entries = private_evidence['evidenceEntries']

        private_evidence_data = {
          'providerFacility' => []
        }

        evidence_entries.each_with_index.map do |entry|
          evidence_entry = entry.dup

          private_evidence_data['privacyAgreementAccepted'] = true if authorization

          if limited_consent_prompt == 'Y' && limited_consent_details.present?
            private_evidence_data['limitedConsent'] =
              limited_consent_details
          end

          facility_data = {
            'providerFacilityName' => evidence_entry['privateTreatmentLocation'] || '',
            'providerFacilityAddress' => {
              'country' => evidence_entry.dig('address', 'country') || '',
              'street' => evidence_entry.dig('address', 'street') || '',
              'street2' => evidence_entry.dig('address', 'street2') || '',
              'city' => evidence_entry.dig('address', 'city') || '',
              'state' => evidence_entry.dig('address', 'state') || '',
              'postalCode' => evidence_entry.dig('address', 'postalCode') || ''
            },
            'issues' => make_issues_list(evidence_entry['issues']),
            'treatmentDateRange' => [{
              'from' => evidence_entry['treatmentStart'] || '',
              'to' => evidence_entry['treatmentEnd'] || ''
            }]
          }

          private_evidence_data['providerFacility'] << facility_data
        end

        private_evidence_data
      end
    end
  end
end
