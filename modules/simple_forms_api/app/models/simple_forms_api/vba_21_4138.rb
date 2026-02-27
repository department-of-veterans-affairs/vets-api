# frozen_string_literal: true

require 'simple_forms_api/overflow_pdf_generator'

module SimpleFormsApi
  class VBA214138 < BaseForm
    STATS_KEY = 'api.simple_forms_api.21_4138'
    REMARKS_SLICE_1 = 0..1510
    REMARKS_SLICE_2 = 1511..3685
    ALLOTTED_REMARKS_LAST_INDEX = REMARKS_SLICE_2.end
    CLAIMANT_TYPE_VETERAN = 'isVeteran'

    def desired_stamps
      [{
        coords: [[35, 220]],
        text: data['statement_of_truth_signature'],
        page: 1
      }]
    end

    def submission_date_stamps(timestamp = Time.current)
      [
        {
          coords: [460, 710],
          text: 'Application Submitted:',
          page: 0,
          font_size: 12
        },
        {
          coords: [460, 690],
          text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
          page: 0,
          font_size: 12
        }
      ]
    end

    def metadata
      id_data = veteran_id_data
      {
        'veteranFirstName' => veteran_full_name.dig('first'),
        'veteranLastName' => veteran_full_name.dig('last'),
        'fileNumber' => id_data['va_file_number'].presence || id_data['ssn'],
        'zipCode' => veteran_mailing_address.dig('postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def veteran_full_name
      data['veteran_full_name'].presence || data['full_name'] || {}
    end

    def veteran_id_data
      data['veteran_id_number'].presence || data['id_number'] || {}
    end

    def veteran_mailing_address
      data['veteran_mailing_address'].presence || data['mailing_address'] || {}
    end

    def veteran_date_of_birth
      data['veteran_date_of_birth'].presence || data['date_of_birth']
    end

    def veteran_phone
      data['veteran_phone'].presence || data['phone']
    end

    def veteran_email
      data['veteran_email_address'].presence || data['email_address']
    end

    def notification_first_name
      data.dig('full_name', 'first')
    end

    def notification_email_address
      data['email_address']
    end

    def zip_code_is_us_based
      data.dig('mailing_address', 'country') == 'USA'
    end

    def remarks_with_claimant_header
      statement = data['statement'].to_s
      return statement if veteran_is_filing?

      "#{build_claimant_header}\n\n#{statement}"
    end

    def overflow_pdf
      statement = (data['statement'] || '').to_s
      return nil if statement.length <= ALLOTTED_REMARKS_LAST_INDEX

      SimpleFormsApi::OverflowPdfGenerator
        .new(data, cutoff: ALLOTTED_REMARKS_LAST_INDEX)
        .generate
    end

    def track_user_identity(confirmation_number); end

    def veteran_is_filing?
      data['claimant_type'] == CLAIMANT_TYPE_VETERAN
    end

    def build_claimant_header
      first = data.dig('full_name', 'first').to_s
      last  = data.dig('full_name', 'last').to_s
      name  = [first, last].compact_blank.join(' ')

      relationship = if data['relationship_to_veteran'] == 'notListed'
                       data['relationship_to_veteran_other'].to_s
                     else
                       data['relationship_to_veteran'].to_s
                     end

      "Submitted by: #{name.presence || 'Not provided'} (#{relationship.presence || 'Not provided'})"
    end
  end
end
