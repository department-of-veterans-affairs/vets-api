# frozen_string_literal: true

module AppealsApi
  class NoticeOfDisagreementPdfOptions
    def initialize(notice_of_disagreement)
      @notice_of_disagreement = notice_of_disagreement
    end

    def veteran_name
      name 'Veteran'
    end

    def veteran_ssn
      header_field_as_string 'X-VA-Veteran-SSN'
    end

    def veteran_file_number
      header_field_as_string 'X-VA-Veteran-File-Number'
    end

    def veteran_dob
      dob 'Veteran'
    end

    def claimant_name
      name 'Claimant'
    end

    def claimant_dob
      dob 'Claimant'
    end

    def contact_info
      @notice_of_disagreement.veteran_contact_info || @notice_of_disagreement.claimant_contact_info
    end

    def address
      address_combined = [
        contact_info.dig('address', 'addressLine1'),
        contact_info.dig('address', 'addressLine2'),
        contact_info.dig('address', 'addressLine3')
      ].compact.map(&:strip).join(' ')

      [
        address_combined,
        contact_info.dig('address', 'city'),
        contact_info.dig('address', 'stateCode'),
        contact_info.dig('address', 'zipCode5'),
        contact_info.dig('address', 'countryName')
      ].compact.map(&:strip).join(', ')
    end

    def homeless?
      contact_info.dig('homeless')
    end

    def phone
      AppealsApi::HigherLevelReview::Phone.new(contact_info&.dig('phone')).to_s
    end

    def email
      contact_info.dig('emailAddressText')
    end

    def representatives_name
      contact_info.dig('representativesName')
    end

    def board_review_option
      @notice_of_disagreement.form_data&.dig('data', 'attributes', 'boardReviewOption')
    end

    def contestable_issues
      @notice_of_disagreement.form_data&.dig('included')
    end

    def date_signed
      veterans_timezone = @notice_of_disagreement.form_data&.dig('data', 'attributes', 'timezone').presence&.strip
      time = veterans_timezone.present? ? Time.now.in_time_zone(veterans_timezone) : Time.now.utc
      time.strftime('%Y-%m-%d')
    end

    def soc_opt_in?
      @notice_of_disagreement.form_data&.dig('data', 'attributes', 'socOptIn')
    end

    def signature
      name = [first_name('Claimant'), last_name('Claimant')]
             .map(&:presence).compact.map(&:strip).join(' ')

      unless name.presence
        name = [first_name('Veteran'), last_name('Veteran')]
               .map(&:presence).compact.map(&:strip).join(' ')
      end

      name
    end

    private

    def name(who)
      [
        first_name(who),
        middle_initial(who),
        last_name(who)
      ].map(&:presence).compact.map(&:strip).join(', ')
    end

    def first_name(who)
      header_field_as_string "X-VA-#{who}-First-Name"
    end

    def middle_initial(who)
      header_field_as_string "X-VA-#{who}-Middle-Initial"
    end

    def last_name(who)
      header_field_as_string "X-VA-#{who}-Last-Name"
    end

    def dob(who)
      header_field_as_string "X-VA-#{who}-Birth-Date"
    end

    def header_field_as_string(key)
      header_field(key).to_s.strip
    end

    def header_field(key)
      @notice_of_disagreement.auth_headers&.dig(key)
    end
  end
end
