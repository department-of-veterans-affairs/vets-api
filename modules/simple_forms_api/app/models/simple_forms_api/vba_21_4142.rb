# frozen_string_literal: true

module SimpleFormsApi
  class VBA214142 < BaseForm
    STATS_KEY = 'api.simple_forms_api.21_4142'

    def words_to_remove
      veteran_ssn + veteran_date_of_birth + veteran_address + patient_identification + veteran_home_phone +
        veteran_email
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran', 'full_name', 'first'),
        'veteranLastName' => @data.dig('veteran', 'full_name', 'last'),
        'fileNumber' => @data.dig('veteran', 'va_file_number').presence || @data.dig('veteran', 'ssn'),
        'zipCode' => @data.dig('veteran', 'address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def notification_first_name
      data.dig('veteran', 'full_name', 'first')
    end

    def notification_email_address
      data.dig('veteran', 'email')
    end

    def zip_code_is_us_based
      @data.dig('veteran', 'address', 'country') == 'USA'
    end

    def desired_stamps
      [{ coords: [50, 560], text: data['statement_of_truth_signature'], page: 1 }]
    end

    def submission_date_stamps(timestamp)
      [submission_date_stamps_first_page(timestamp), submission_date_stamps_fourth_page(timestamp)].flatten
    end

    def track_user_identity(confirmation_number)
      identity = data.dig('preparer_identification', 'relationship_to_veteran')
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('Simple forms api - 21-4142 submission user identity', identity:, confirmation_number:)
    end

    private

    def veteran_ssn
      [
        data.dig('veteran', 'ssn')&.[](0..2),
        data.dig('veteran', 'ssn')&.[](3..4),
        data.dig('veteran', 'ssn')&.[](5..8)
      ]
    end

    def veteran_date_of_birth
      [
        data.dig('veteran', 'date_of_birth')&.[](0..3),
        data.dig('veteran', 'date_of_birth')&.[](5..6),
        data.dig('veteran', 'date_of_birth')&.[](8..9)
      ]
    end

    def veteran_address
      [
        data.dig('veteran', 'address', 'postal_code')&.[](0..4),
        data.dig('veteran', 'address', 'postal_code')&.[](5..8)
      ]
    end

    def patient_identification
      [
        data.dig('patient_identification', 'patient_ssn')&.[](0..2),
        data.dig('patient_identification', 'patient_ssn')&.[](3..4),
        data.dig('patient_identification', 'patient_ssn')&.[](5..8)
      ]
    end

    def veteran_home_phone
      [
        data.dig('veteran', 'home_phone')&.gsub('-', '')&.[](0..2),
        data.dig('veteran', 'home_phone')&.gsub('-', '')&.[](3..5),
        data.dig('veteran', 'home_phone')&.gsub('-', '')&.[](6..9)
      ]
    end

    def veteran_email
      [
        data.dig('veteran', 'email')&.[](0..14),
        data.dig('veteran', 'email')&.[](15..)
      ]
    end

    def submission_date_stamps_first_page(timestamp)
      [
        {
          coords: [440, 710],
          text: 'Application Submitted:',
          page: 0,
          font_size: 12
        },
        {
          coords: [440, 690],
          text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
          page: 0,
          font_size: 12
        }
      ]
    end

    def submission_date_stamps_fourth_page(timestamp)
      [
        {
          coords: [440, 710],
          text: 'Application Submitted:',
          page: 3,
          font_size: 12
        },
        {
          coords: [440, 690],
          text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
          page: 3,
          font_size: 12
        }
      ]
    end
  end
end
