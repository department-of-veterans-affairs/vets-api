# frozen_string_literal: true

require_rel '../form_engine'

module SimpleFormsApi
  class VBA214140 < BaseForm
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
      @signature = data['statement_of_truth_signature']
      @signature_date_formatted = signature_date.strftime('%m/%d/%Y')
    end

    def desired_stamps
      coords = employed? ? [[50, 410]] : [[50, 275]]
      [{ coords:, text: signature, page: 1 }]
    end

    def dob
      # date_of_birth is in YYYY-MM-DD format
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
        'fileNumber' => data['va_file_number'].presence || data['ssn'],
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
      data['mobile_phone'].insert(-8, '-').insert(-5, '-')
    end

    def phone_primary
      data['home_phone'].insert(-8, '-').insert(-5, '-')
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
      trimmed_ssn = data.dig('veteran_id', 'ssn')&.tr('-', '')

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

    # At the moment, we only allow veterans to submit Form Engine forms.
    def track_user_identity(confirmation_number); end

    def words_to_remove
      ssn + dob + address_to_remove + contact_info
    end

    def zip_code_is_us_based
      address.country_code_iso3 == 'USA'
    end

    private

    attr_reader :signature, :signature_date_formatted

    def address_to_remove
      [address.address_line1, address.address_line2, address.zip_code]
    end

    def contact_info
      [phone_primary, phone_alternate, data['email_address']]
    end
  end
end
