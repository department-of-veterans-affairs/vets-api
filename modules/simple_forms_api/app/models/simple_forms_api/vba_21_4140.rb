# frozen_string_literal: true

require_rel '../form_engine'

module SimpleFormsApi
  class VBA214140 < BaseForm
    STATS_KEY = 'api.simple_forms_api.21_4140'
    attr_reader :address

    def initialize(data)
      super

      @address = FormEngine::Address.new(
        address_line1: data.dig('address', 'street'),
        address_line2: data.dig('address', 'street2'),
        city: data.dig('address', 'city'),
        country_code_iso3: data.dig('address', 'country'),
        state_code: data.dig('address', 'state'),
        zip_code: data.dig('address', 'postal_code')
      )
    end

    def desired_stamps
      coords = employed? ? [[50, 410]] : [[50, 275]]
      signature_text = data['statement_of_truth_signature']

      [{ coords:, text: signature_text, page: 1 }]
    end

    def dob
      trimmed_dob = data['date_of_birth']&.tr('-', '')
      [trimmed_dob&.[](0..3), trimmed_dob&.[](4..5), trimmed_dob&.[](6..7)]
    end

    def employed?
      employers.any?
    end

    def employers
      data['employers']&.delete_if(&:empty?) || []
    end

    def employment_history
      [*0..3].map { |i| FormEngine::EmploymentHistory.new(employers[i]) }
    end

    def first_name
      data.dig('full_name', 'first')&.[](0..11)
    end

    def last_name
      data.dig('full_name', 'last')&.[](0..17)
    end

    def metadata
      {
        'veteranFirstName' => data.dig('full_name', 'first'),
        'veteranLastName' => data.dig('full_name', 'last'),
        'fileNumber' => data.dig('id_number', 'va_file_number').presence || data.dig('id_number', 'ssn'),
        'zipCode' => data.dig('address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def middle_initial
      data.dig('full_name', 'middle')&.[](0)
    end

    def phone_alternate
      format_phone(data['mobile_phone_number'])
    end

    def phone_primary
      format_phone(data['phone_number'])
    end

    def signature_date_employed
      employed? ? signature_date_formatted : nil
    end

    def signature_date_unemployed
      employed? ? nil : signature_date_formatted
    end

    def signature_employed
      employed? ? signature : nil
    end

    def signature_unemployed
      employed? ? nil : signature
    end

    def ssn
      trimmed_ssn = data.dig('id_number', 'ssn')&.tr('-', '')
      [trimmed_ssn&.[](0..2), trimmed_ssn&.[](3..4), trimmed_ssn&.[](5..8)]
    end

    def submission_date_stamps(timestamp = Time.current)
      [
        {
          coords: [450, 670],
          text: 'Application Submitted:',
          page: 0,
          font_size: 12
        },
        {
          coords: [450, 650],
          text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
          page: 0,
          font_size: 12
        }
      ]
    end

    def track_user_identity(confirmation_number)
      identity = employed? ? 'employed' : 'unemployed'
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('Simple forms api - 21-4140 submission user identity', identity:, confirmation_number:)
    end

    def words_to_remove
      ssn + dob + address_to_remove + contact_info
    end

    def zip_code_is_us_based
      address.country_code_iso3 == 'USA'
    end

    def get_attachments
      return [] unless data['supporting_evidence']

      attachment_guids = data['supporting_evidence'].map { |doc| doc['confirmation_code'] }.compact
      PersistentAttachment.where(guid: attachment_guids).map(&:to_pdf)
    end

    def notification_email_address
      data['email'] = data['email_address']
      data['email_address']
    end

    private

    def signature
      data['statement_of_truth_signature']
    end

    def signature_date_formatted
      signature_date.strftime('%m/%d/%Y')
    end

    def address_to_remove
      [address.address_line1, address.address_line2, address.zip_code].compact
    end

    def contact_info
      [data['phone_number'], data['mobile_phone_number'], data['email_address']].compact
    end

    def format_phone(phone)
      return nil if phone.nil?

      "#{phone[0...-7]}-#{phone[-7...-4]}-#{phone[-4..]}"
    end
  end
end
