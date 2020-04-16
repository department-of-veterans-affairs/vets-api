# frozen_string_literal: true

module AppealsApi
  class HigherLevelReview < ApplicationRecord
    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

    enum status: { pending: 0, submitted: 1, established: 2, errored: 3 }

    INFORMAL_CONFERENCE_REP_NAME_AND_PHONE_MAX_LENGTH = 100
    FIRST_NAME_MAX_LENGTH = 12
    MIDDLE_INITIAL_LENGTH = 1
    LAST_NAME_MAX_LENGTH = 18
    FILE_NUMBER_MAX_LENGTH = 9
    SERVICE_NUMBER_MAX_LENGTH = 9
    INSURANCE_POLICY_NUMBER_MAX_LENGTH = 18

    # beyond json schema validations:
    # (form_data is mostly validated with modules/appeals_api/config/schemas/200996.json)
    validate(
      :veteran_phone_is_not_too_long,
      :informal_conference_rep_name_and_phone_is_not_too_long,
      :contestable_issue_dates_are_valid_dates
    )

    # header validations:
    validate(
      :ssn_present,
      :first_name_present,
      :last_name_present,
      :birth_date_present,
      :ssn_is_9_digits,
      :first_name_is_not_too_long,
      :middle_initial_is_correct_length,
      :last_name_is_not_too_long,
      :birth_date_is_a_date,
      :birth_date_is_in_the_past,
      :file_number_is_not_too_long,
      :service_number_is_not_too_long,
      :insurance_policy_number_is_not_too_long
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

    def informal_conference_rep_name_and_phone_is_too_long?
      informal_conference_rep_name_and_phone.length > INFORMAL_CONFERENCE_REP_NAME_AND_PHONE_MAX_LENGTH
    end

    def first_name_is_too_long?
      first_name && first_name.length > FIRST_NAME_MAX_LENGTH
    end

    def middle_initial_is_correct_length?
      middle_initial && middle_initial.length == MIDDLE_INITIAL_LENGTH
    end

    def last_name_is_too_long?
      last_name && last_name.length > LAST_NAME_MAX_LENGTH
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

    def file_number_is_too_long?
      file_number && file_number.length > FILE_NUMBER_MAX_LENGTH
    end

    def service_number_is_too_long?
      service_number && service_number.length > SERVICE_NUMBER_MAX_LENGTH
    end

    def insurance_policy_number_is_too_long?
      insurance_policy_number && insurance_policy_number.length > INSURANCE_POLICY_NUMBER_MAX_LENGTH
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
    def ssn_present
      errors.add(:base, "header 'X-VA-SSN' must be present") unless ssn
    end

    # validation (header)
    def first_name_present
      errors.add(:base, "header 'X-VA-First-Name' must be present") unless first_name
    end

    # validation (header)
    def last_name_present
      errors.add(:base, "header 'X-VA-Last-Name' must be present") unless last_name
    end

    # validation (header)
    def birth_date_present
      errors.add(:base, "header 'X-VA-Birth-Date' must be present") unless birth_date
    end

    # validation (header)
    def ssn_is_9_digits
      return unless ssn

      regex = '^[0-9]{9}$'
      errors.add(:base, "Veteran SSN must match regex '#{regex}': #{ssn}") unless ssn.match regex
    end

    # validation (header)
    def first_name_is_not_too_long
      return unless first_name_is_too_long?

      errors.add(
        :base,
        "Veteran first name is too long (#{FIRST_NAME_MAX_LENGTH} char limit): #{first_name}"
      )
    end

    # validation (header)
    def middle_initial_is_correct_length
      return if middle_initial_is_correct_length?

      errors.add(
        :base,
        "If included, veteran middle initial must be #{MIDDLE_INITIAL_LENGTH} character(s) long: #{middle_initial}"
      )
    end

    # validation (header)
    def last_name_is_not_too_long
      return unless last_name_is_too_long?

      errors.add(
        :base,
        "Veteran last name is too long (#{LAST_NAME_MAX_LENGTH} char limit): #{last_name}"
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

    # validation (header)
    def file_number_is_not_too_long
      return unless file_number_is_too_long?

      errors.add(
        :base,
        "Veteran file_number is too long (#{FILE_NUMBER_MAX_LENGTH} char limit): #{file_number}"
      )
    end

    # validation (header)
    def service_number_is_not_too_long
      return unless service_number_is_too_long?

      errors.add(
        :base,
        "Veteran service_number is too long (#{SERVICE_NUMBER_MAX_LENGTH} char limit): #{service_number}"
      )
    end

    # validation (header)
    def insurance_policy_number_is_not_too_long
      return unless insurance_policy_number_is_too_long?

      errors.add(
        :base,
        'Veteran insurance policy_number is too long' \
        " (#{INSURANCE_POLICY_NUMBER_MAX_LENGTH} char limit): #{insurance_policy_number}"
      )
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
