# frozen_string_literal: true

module FormIntake
  module Mappers
    # Mapper for form 21P-0537 (Application for Pension Benefits - Report of Remarriage)
    class VBA21p0537Mapper < BaseMapper
      def to_gcio_payload
        {
          form_number: '21P-0537',
          submission_id: form_submission_id,
          benefits_intake_uuid:,
          submitted_at: @form_submission.created_at.iso8601,
          veteran: map_veteran,
          recipient: map_recipient,
          has_remarried: form_data['hasRemarried'],
          remarriage: map_remarriage,
          in_reply_refer_to: form_data['inReplyReferTo']
        }.compact
      end

      private

      def map_veteran
        veteran_data = form_data['veteran']
        return nil unless veteran_data

        {
          first_name: veteran_data.dig('fullName', 'first'),
          middle_name: veteran_data.dig('fullName', 'middle'),
          last_name: veteran_data.dig('fullName', 'last'),
          ssn: map_ssn(veteran_data['ssn']),
          va_file_number: veteran_data['vaFileNumber'].presence
        }.compact
      end

      def map_recipient
        recipient_data = form_data['recipient']
        return nil unless recipient_data

        {
          first_name: recipient_data.dig('fullName', 'first'),
          middle_name: recipient_data.dig('fullName', 'middle'),
          last_name: recipient_data.dig('fullName', 'last'),
          phone: map_recipient_phone(recipient_data['phone']),
          email: recipient_data['email'],
          signature: recipient_data['signature'],
          signature_date: map_date(recipient_data['signatureDate'])
        }.compact
      end

      def map_recipient_phone(phone_data)
        return nil unless phone_data

        phones = {}

        if phone_data['daytime']
          daytime = map_phone_camel_case(phone_data['daytime'])
          phones[:daytime] = daytime if daytime
        end

        if phone_data['evening']
          evening = map_phone_camel_case(phone_data['evening'])
          phones[:evening] = evening if evening
        end

        phones.presence
      end

      # Map phone with camelCase keys (specific to 21P-0537 format)
      def map_phone_camel_case(phone_parts)
        return nil unless phone_parts

        area_code = phone_parts['areaCode']
        prefix = phone_parts['prefix']
        line_number = phone_parts['lineNumber']

        return nil if area_code.blank? || prefix.blank? || line_number.blank?

        "#{area_code}#{prefix}#{line_number}"
      end

      def map_remarriage
        return nil unless form_data['hasRemarried']

        remarriage_data = form_data['remarriage']
        return nil unless remarriage_data

        {
          date_of_marriage: map_date(remarriage_data['dateOfMarriage']),
          spouse_name: map_spouse_name(remarriage_data['spouseName']),
          spouse_date_of_birth: map_date(remarriage_data['spouseDateOfBirth']),
          spouse_is_veteran: remarriage_data['spouseIsVeteran'],
          age_at_marriage: remarriage_data['ageAtMarriage'],
          spouse_ssn: map_ssn(remarriage_data['spouseSSN']),
          spouse_va_file_number: remarriage_data['spouseVAFileNumber'].presence,
          has_terminated: remarriage_data['hasTerminated'],
          termination_date: map_termination_date(remarriage_data),
          termination_reason: remarriage_data['terminationReason'].presence
        }.compact
      end

      def map_spouse_name(name_data)
        return nil unless name_data

        {
          first: name_data['first'],
          middle: name_data['middle'],
          last: name_data['last']
        }.compact.presence
      end

      def map_termination_date(remarriage_data)
        return nil unless remarriage_data['hasTerminated']

        termination_date = remarriage_data['terminationDate']
        return nil unless termination_date
        return nil if termination_date['year'].blank?

        map_date(termination_date)
      end
    end
  end
end

