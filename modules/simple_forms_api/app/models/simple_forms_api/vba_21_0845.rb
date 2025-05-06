# frozen_string_literal: true

module SimpleFormsApi
  class VBA210845 < BaseForm
    STATS_KEY = 'api.simple_forms_api.21_0845'

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran_full_name', 'first'),
        'veteranLastName' => @data.dig('veteran_full_name', 'last'),
        'fileNumber' => @data['veteran_va_file_number'].presence || @data['veteran_ssn'],
        'zipCode' => @data.dig('authorizer_address', 'postal_code') ||
          @data.dig('person_address', 'postal_code') ||
          @data.dig('organization_address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def notification_first_name
      if data['authorizer_type'] == 'veteran'
        data.dig('veteran_full_name', 'first')
      elsif data['authorizer_type'] == 'nonVeteran'
        data.dig('authorizer_full_name', 'first')
      end
    end

    def notification_email_address
      if data['authorizer_type'] == 'veteran'
        data['veteran_email']
      elsif data['authorizer_type'] == 'nonVeteran'
        data['authorizer_email']
      end
    end

    def zip_code_is_us_based
      @data.dig('authorizer_address',
                'country') == 'USA' || @data.dig('person_address',
                                                 'country') == 'USA' || @data.dig('organization_address',
                                                                                  'country') == 'USA'
    end

    def words_to_remove
      veteran_ssn + veteran_date_of_birth + authorizer_address + authorizer_phone +
        person_address + organization_address
    end

    def desired_stamps
      [{ coords: [50, 240], text: data['statement_of_truth_signature'], page: 2 }]
    end

    def submission_date_stamps(timestamp = Time.current)
      [
        {
          coords: [460, 710],
          text: 'Application Submitted:',
          page: 1,
          font_size: 12
        },
        {
          coords: [460, 690],
          text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
          page: 1,
          font_size: 12
        }
      ]
    end

    def track_user_identity(confirmation_number)
      identity = "#{data['authorizer_type']} #{data['third_party_type']}"
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('Simple forms api - 21-0845 submission user identity', identity:, confirmation_number:)
    end

    private

    def veteran_ssn
      [
        data['veteran_ssn']&.[](0..2),
        data['veteran_ssn']&.[](3..4),
        data['veteran_ssn']&.[](5..8)
      ]
    end

    def veteran_date_of_birth
      [
        data['veteran_date_of_birth']&.[](0..3),
        data['veteran_date_of_birth']&.[](5..6),
        data['veteran_date_of_birth']&.[](8..9)
      ]
    end

    def authorizer_address
      [
        data.dig('authorizer_address', 'postal_code')&.[](0..4),
        data.dig('authorizer_address', 'postal_code')&.[](5..8)
      ]
    end

    def authorizer_phone
      [
        data['authorizer_phone']&.gsub('-', '')&.[](0..2),
        data['authorizer_phone']&.gsub('-', '')&.[](3..5),
        data['authorizer_phone']&.gsub('-', '')&.[](6..9)
      ]
    end

    def person_address
      [
        data.dig('person_address', 'postal_code')&.[](0..4),
        data.dig('person_address', 'postal_code')&.[](5..8)
      ]
    end

    def organization_address
      [
        data.dig('organization_address', 'postal_code')&.[](0..4),
        data.dig('organization_address', 'postal_code')&.[](5..8)
      ]
    end
  end
end
