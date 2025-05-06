# frozen_string_literal: true

module SimpleFormsApi
  class VBA2010206 < BaseForm
    STATS_KEY = 'api.simple_forms_api.20_10206'

    def metadata
      {
        'veteranFirstName' => @data.dig('full_name', 'first'),
        'veteranLastName' => @data.dig('full_name', 'last'),
        'fileNumber' => @data.dig(
          'citizen_id',
          'ssn'
        ) || @data.dig(
          'citizen_id',
          'va_file_number'
        ) || @data.dig(
          'non_citizen_id',
          'arn'
        ),
        'zipCode' => @data.dig('address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def notification_first_name
      data.dig('full_name', 'first')
    end

    def notification_email_address
      data['email_address']
    end

    def zip_code_is_us_based
      @data.dig('address', 'country') == 'USA'
    end

    def words_to_remove
      citizen_ssn + address + date_of_birth + home_phone
    end

    def desired_stamps
      []
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
      identity = data['preparer_type']
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('Simple forms api - 20-10206 submission user identity', identity:, confirmation_number:)
    end

    private

    def citizen_ssn
      [
        data.dig('citizen_id', 'ssn')&.[](0..2),
        data.dig('citizen_id', 'ssn')&.[](3..4),
        data.dig('citizen_id', 'ssn')&.[](5..8)
      ]
    end

    def address
      [data.dig('address', 'postal_code')&.[](0..4), data.dig('address', 'postal_code')&.[](5..8)]
    end

    def date_of_birth
      [
        data['date_of_birth']&.[](0..3),
        data['date_of_birth']&.[](5..6),
        data['date_of_birth']&.[](8..9)
      ]
    end

    def home_phone
      [
        data['home_phone']&.gsub('-', '')&.[](0..2),
        data['home_phone']&.gsub('-', '')&.[](3..5),
        data['home_phone']&.gsub('-', '')&.[](6..9)
      ]
    end
  end
end
