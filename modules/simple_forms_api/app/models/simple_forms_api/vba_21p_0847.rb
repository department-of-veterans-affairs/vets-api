# frozen_string_literal: true

module SimpleFormsApi
  class VBA21p0847 < BaseForm
    STATS_KEY = 'api.simple_forms_api.21p_0847'

    def words_to_remove
      veteran_ssn + veteran_date_of_birth + deceased_claimant_date_of_death + preparer_ssn + preparer_address
    end

    def metadata
      {
        'veteranFirstName' => data.dig('deceased_claimant_full_name', 'first'),
        'veteranLastName' => data.dig('deceased_claimant_full_name', 'last'),
        'fileNumber' => data['veteran_va_file_number'].presence || data['veteran_ssn'],
        'zipCode' => data.dig('preparer_address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def notification_first_name
      data.dig('preparer_name', 'first')
    end

    def notification_email_address
      data['preparer_email']
    end

    def zip_code_is_us_based
      @data.dig('preparer_address', 'country') == 'USA'
    end

    def desired_stamps
      [{ coords: [50, 190], text: data['statement_of_truth_signature'], page: 1 }]
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
      identity = data.dig('relationship_to_deceased_claimant', 'other_relationship_to_veteran') ||
                 data.dig('relationship_to_deceased_claimant', 'relationship_to_veteran')
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('Simple forms api - 21P-0847 submission user identity', identity:, confirmation_number:)
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

    def deceased_claimant_date_of_death
      [
        data['deceased_claimant_date_of_death']&.[](0..3),
        data['deceased_claimant_date_of_death']&.[](5..6),
        data['deceased_claimant_date_of_death']&.[](8..9)
      ]
    end

    def preparer_ssn
      [
        data['preparer_ssn']&.[](0..2),
        data['preparer_ssn']&.[](3..4),
        data['preparer_ssn']&.[](5..8)
      ]
    end

    def preparer_address
      [
        data.dig('preparer_address', 'postal_code')&.[](0..4),
        data.dig('preparer_address', 'postal_code')&.[](5..8)
      ]
    end
  end
end
