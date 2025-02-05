# frozen_string_literal: true

module SimpleFormsApi
  class VBA2110210 < BaseForm
    STATS_KEY = 'api.simple_forms_api.21_10210'

    def metadata
      {
        'veteranFirstName' => data.dig('veteran_full_name', 'first'),
        'veteranLastName' => data.dig('veteran_full_name', 'last'),
        'fileNumber' => data['veteran_va_file_number'].presence || data['veteran_ssn'],
        'zipCode' => data.dig('veteran_mailing_address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def notification_first_name
      if data['claim_ownership'] == 'self' && @data['claimant_type'] == 'veteran'
        data.dig('veteran_full_name', 'first')
      elsif data['claim_ownership'] == 'self' && @data['claimant_type'] == 'non-veteran'
        data.dig('claimant_full_name', 'first')
      elsif data['claim_ownership'] == 'third-party'
        data.dig('witness_full_name', 'first')
      end
    end

    def notification_email_address
      if data['claim_ownership'] == 'self' && @data['claimant_type'] == 'veteran'
        data['veteran_email']
      elsif data['claim_ownership'] == 'self' && @data['claimant_type'] == 'non-veteran'
        data['claimant_email']
      elsif data['claim_ownership'] == 'third-party'
        data['witness_email']
      end
    end

    def zip_code_is_us_based
      @data.dig('veteran_mailing_address', 'country') == 'USA'
    end

    def words_to_remove
      veteran_ssn + veteran_date_of_birth + veteran_mailing_address + veteran_phone + veteran_email +
        claimant_ssn + claimant_date_of_birth + claimant_mailing_address + claimant_phone + claimant_email +
        statement + witness_phone + witness_email
    end

    def desired_stamps
      [{ coords: [50, 195], text: data['statement_of_truth_signature'], page: 2 }]
    end

    def submission_date_stamps(timestamp = Time.current)
      [
        {
          coords: [452, 690],
          text: 'Application Submitted:',
          page: 0,
          font_size: 12
        },
        {
          coords: [452, 670],
          text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
          page: 0,
          font_size: 12
        }
      ]
    end

    def track_user_identity(confirmation_number)
      identity = "#{data['claimant_type']} #{data['claim_ownership']}"
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('Simple forms api - 21-10210 submission user identity', identity:, confirmation_number:)
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

    def veteran_mailing_address
      [
        data.dig('veteran_mailing_address', 'postal_code')&.[](0..4),
        data.dig('veteran_mailing_address', 'postal_code')&.[](5..8)
      ]
    end

    def veteran_phone
      [
        data['veteran_phone']&.gsub('-', '')&.[](0..2),
        data['veteran_phone']&.gsub('-', '')&.[](3..5),
        data['veteran_phone']&.gsub('-', '')&.[](6..9)
      ]
    end

    def veteran_email
      [
        data['veteran_email']&.[](0..19),
        data['veteran_email']&.[](20..39)
      ]
    end

    def claimant_ssn
      [
        data['claimant_ssn']&.[](0..2),
        data['claimant_ssn']&.[](3..4),
        data['claimant_ssn']&.[](5..8)
      ]
    end

    def claimant_date_of_birth
      [
        data['claimant_date_of_birth']&.[](0..3),
        data['claimant_date_of_birth']&.[](5..6),
        data['claimant_date_of_birth']&.[](8..9)
      ]
    end

    def claimant_mailing_address
      [
        data.dig('claimant_mailing_address', 'postal_code')&.[](0..4),
        data.dig('claimant_mailing_address', 'postal_code')&.[](5..8)
      ]
    end

    def claimant_phone
      [
        data['claimant_phone']&.gsub('-', '')&.[](0..2),
        data['claimant_phone']&.gsub('-', '')&.[](3..5),
        data['claimant_phone']&.gsub('-', '')&.[](6..9)
      ]
    end

    def claimant_email
      [
        data['claimant_email']&.[](0..19),
        data['claimant_email']&.[](20..39)
      ]
    end

    def statement
      [
        data['statement']&.[](0..5554),
        data['statement']&.[](5555..)
      ]
    end

    def witness_phone
      [
        data['witness_phone']&.gsub('-', '')&.[](0..2),
        data['witness_phone']&.gsub('-', '')&.[](3..5),
        data['witness_phone']&.gsub('-', '')&.[](6..9)
      ]
    end

    def witness_email
      [
        data['witness_email']&.[](0..19),
        data['witness_email']&.[](20..39)
      ]
    end
  end
end
