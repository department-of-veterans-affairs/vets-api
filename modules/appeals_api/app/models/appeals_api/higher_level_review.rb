# frozen_string_literal: true

module AppealsApi
  class HigherLevelReview < ApplicationRecord
    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

    enum status: { pending: 0, processing: 1, submitted: 2, established: 3, errored: 4 }

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

    # 1. VETERAN'S NAME
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

    # 2. VETERAN'S SOCIAL SECURITY NUMBER
    def ssn
      header 'X-VA-SSN'
    end

    # 3. VA FILE NUMBER
    def file_number
      header 'X-VA-File-Number'
    end

    # 4. VETERAN'S DATE OF BIRTH
    def birth_mm
      birth_date.strftime '%m'
    end

    def birth_dd
      birth_date.strftime '%d'
    end

    def birth_yyyy
      birth_date.strftime '%Y'
    end

    # 5. VETERAN'S SERVICE NUMBER
    def service_number
      header 'X-VA-Service-Number'
    end

    # 6. INSURANCE POLICY NUMBER
    def insurance_policy_number
      header 'X-VA-Insurance-Policy-Number'
    end

    # 7. CLAIMANT'S NAME
    # 8. CLAIMANT TYPE

    # 9. CURRENT MAILING ADDRESS
    def number_and_street
      address&.dig('addressLine1')
    end

    def apt_unit_number
      address&.dig('addressLine2')
    end

    def city
      address&.dig('cityName')
    end

    def state_code
      address&.dig('stateCode')
    end

    def country_code
      address&.dig('countryCodeISO2') || 'US'
    end

    def zip_code_5
      address&.dig('zipCode5')
    end

    def zip_code_4
      address&.dig('zipCode4')
    end

    # 10. TELEPHONE NUMBER
    def veteran_phone
      AppealsApi::HigherLevelReview::Phone.new veteran&.dig('phone')
    end

    # 11. E-MAIL ADDRESS
    def email
      veteran&.dig('emailAddressText')
    end

    # 12. BENEFIT TYPE
    def benefit_type
      data_attributes&.dig('benefitType')
    end

    # 13. IF YOU WOULD LIKE THE SAME OFFICE...
    def same_office?
      data_attributes&.dig('sameOffice')
    end

    # 14. ...INFORMAL CONFERENCE...
    def informal_conference?
      data_attributes&.dig('informalConference')
    end

    def informal_conference_times
      data_attributes&.dig('informalConferenceTimes')
    end

    def informal_conference_rep_name_and_phone
      "#{informal_conference_rep_name} #{informal_conference_rep_phone}"
    end

    # 15. YOU MUST INDICATE BELOW EACH ISSUE...
    def contestable_issues
      form_data&.dig('included')
    end

    private

    def data_attributes
      form_data&.dig('data', 'attributes')
    end

    def veteran
      data_attributes&.dig('veteran')
    end

    def address
      veteran&.dig('address')
    end

    def birth_date
      Date.parse header 'X-VA-Birth-Date'
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

    def informal_conference_rep
      data_attributes&.dig('informalConferenceRep')
    end

    def informal_conference_rep_name
      informal_conference_rep&.dig('name')
    end

    def informal_conference_rep_phone
      AppealsApi::HigherLevelReview::Phone.new(informal_conference_rep&.dig('phone'))
    end

    def informal_conference_rep_name_and_phone_is_too_long?
      informal_conference_rep_name_and_phone.length > INFORMAL_CONFERENCE_REP_NAME_AND_PHONE_MAX_LENGTH
    end

    # treat blank headers as nil
    def header(key)
      val = auth_headers&.dig(key)
      val.blank? ? nil : val.to_s
    end

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
        "Veteran birth date isn't a date: #{header 'X-VA-Birth-Date'}"
      )
    end

    # validation (header)
    def birth_date_is_in_the_past
      return if birth_date_is_in_the_past?

      errors.add(:base, "Veteran birth date isn't in the past: #{header 'X-VA-Birth-Date'}")
    end

    # validation
    def contestable_issue_dates_are_valid_dates
      return unless contestable_issues

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
