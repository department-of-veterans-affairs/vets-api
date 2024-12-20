# frozen_string_literal: true

module SimpleFormsApi
  class VBA214140 < BaseForm
    def desired_stamps
      []
    end

    def dob
      # date_of_birth is in YYYY-MM-DD format
      trimmed_dob = data['date_of_birth']&.tr('-', '')

      [trimmed_dob&.[](0..3), trimmed_dob&.[](4..5), trimmed_dob&.[](6..7)]
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

    def phone_primary
      data['home_phone'].insert(-8, '-').insert(-5, '-')
    end

    def ssn
      trimmed_ssn = data.dig('veteran_id', 'ssn')&.tr('-', '')

      [trimmed_ssn&.[](0..2), trimmed_ssn&.[](3..4), trimmed_ssn&.[](5..8)]
    end

    def submission_date_stamps(_timestamp)
      []
    end

    # At the moment, we only allow veterans to submit Form Engine forms.
    def track_user_identity(confirmation_number); end

    def zip_code_is_us_based
      data.dig('address', 'country') == 'USA'
    end
  end
end
