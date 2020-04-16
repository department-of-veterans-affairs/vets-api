# frozen_string_literal: true

module AppealsApi
  class HigherLevelReview < ApplicationRecord
    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

    enum status: { pending: 0, submitted: 1, established: 2, errored: 3 }

    INFORMAL_CONFERENCE_REP_NAME_AND_PHONE_MAX_LENGTH = 100

    # beyond json schema validations:
    # (form_data is mostly validated with modules/appeals_api/config/schemas/200996.json)
    validate(
      :veteran_phone_is_not_too_long,
      :informal_conference_rep_name_and_phone_is_not_too_long,
      :birth_date_is_a_date,
      :birth_date_is_in_the_past,
      :contestable_issue_dates_are_valid_dates
    )

    def country
      form_data&.dig('data', 'attributes', 'veteran', 'address', 'countryCodeISO2') || 'US'
    end

    def veteran_phone
      AppealsApi::HigherLevelReview::Phone.new(
        form_data&.dig('data', 'attributes', 'veteran', 'phone')
      )
    end

    def informal_conference_rep_name
      form_data&.dig('data', 'attributes', 'informalConferenceRep', 'name')
    end

    def informal_conference_rep_phone
      AppealsApi::HigherLevelReview::Phone.new(
        form_data&.dig('data', 'attributes', 'informalConferenceRep', 'phone')
      )
    end

    def informal_conference_rep_name_and_phone
      "#{informal_conference_rep_name} #{informal_conference_rep_phone}"
    end

    def ssn
      header 'X-VA-SSN'
    end

    def first_name
      # whitespace first name OK
      auth_headers&.dig 'X-VA-First-Name'
    end

    def middle_initial
      header 'X-VA-Middle-Initial'
    end

    def last_name
      header 'X-VA-Last-Name'
    end

    def birth_date
      Date.parse header 'X-VA-Birth-Date'
    end

    def birth_yyyy
      birth_date.strftime '%Y'
    end

    def birth_mm
      birth_date.strftime '%m'
    end

    def birth_dd
      birth_date.strftime '%d'
    end

    def file_number
      header 'X-VA-File-Number'
    end

    def service_number
      header 'X-VA-Service-Number'
    end

    def insurance_policy_number
      header 'X-VA-Insurance-Policy-Number'
    end

    def birth_date_is_a_date?
      birth_date
      true
    rescue
      false
    end

    def birth_date_is_in_the_past?
      birth_date_is_a_date? && birth_date < Time.zone.today
    end

    # treat blank headers as nil
    def header(key)
      val = auth_headers&.dig(key)
      val.blank? ? nil : val.to_s
    end

    private

    # validation
    def veteran_phone_is_not_too_long
      return unless veteran_phone.too_long?

      limit = "#{AppealsApi::HigherLevelReview::Phone::MAX_LENGTH} char limit"
      errors.add(:base, "Veteran phone number will not fit on form (#{limit}): #{veteran_phone}")
    end

    # validation
    def informal_conference_rep_name_and_phone_is_not_too_long
      return unless informal_conference_rep_name_and_phone_is_too_long?

      errors.add(
        :base,
        [
          'Informal conference rep will not fit on form',
          "(#{INFORMAL_CONFERENCE_REP_NAME_AND_PHONE_MAX_LENGTH} char limit):",
          informal_conference_rep_name_and_phone
        ].join(' ')
      )
    end

    # validation (header)
    def birth_date_is_a_date
      return if birth_date_is_a_date?

      errors.add(
        :base,
        "Veteran birth date isn't a date: #{auth_headers&.dig('X-VA-Birth-Date')}"
      )
    end

    # validation (header)
    def birth_date_is_in_the_past
      return if birth_date_is_in_the_past?

      errors.add(:base, "Veteran birth date isn't in the past: #{birth_date}")
    end

    # validation
    def contestable_issue_dates_are_valid_dates
      contestable_issues.each_with_index do |contestable_issue, index|
        decision_date_string = contestable_issue&.dig('attributes', 'decisionDate')
        begin
          decision_date = Date.parse decision_date_string
          unless decision_date < Time.zone.today
            errors.add(
              :base,
              "included[#{index}].attributes.decisionDate isn't in the past: #{decision_date_string}"
            )
          end
        rescue
          errors.add(
            :base,
            "included[#{index}].attributes.decisionDate isn't a valid date: #{decision_date_string}"
          )
        end
      end
    end
  end
end
