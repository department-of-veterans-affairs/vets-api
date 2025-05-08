# frozen_string_literal: true

module SimpleFormsApi
  class VBA2010207 < BaseForm
    STATS_KEY = 'api.simple_forms_api.20_10207'

    def facility_name(index)
      facility = @data['medical_treatments']&.[](index - 1)
      "#{facility&.[]('facility_name')}\\n#{facility_address(index)}" if facility
    end

    def facility_address(index)
      facility = @data['medical_treatments']&.[](index - 1)
      address = facility&.[]('facility_address')
      "#{address&.[]('street')}" \
        "#{address&.[]('city')}, #{address&.[]('state')}\\n#{address&.[]('postal_code')}\\n" \
        "#{address&.[]('country')}"
    end

    def facility_month(index)
      facility = @data['medical_treatments']&.[](index - 1)
      facility&.[]('start_date')&.[](5..6)
    end

    def facility_day(index)
      facility = @data['medical_treatments']&.[](index - 1)
      facility&.[]('start_date')&.[](8..9)
    end

    def facility_year(index)
      facility = @data['medical_treatments']&.[](index - 1)
      facility&.[]('start_date')&.[](0..3)
    end

    def requester_signature
      @data['statement_of_truth_signature'] if %w[veteran non-veteran].include? @data['preparer_type']
    end

    def third_party_signature
      @data['statement_of_truth_signature'] if %w[third-party-veteran
                                                  third-party-non-veteran].include? @data['preparer_type']
    end

    def power_of_attorney_signature
      @data['statement_of_truth_signature'] if @data['third_party_type'] == 'power-of-attorney'
    end

    def words_to_remove
      veteran_ssn + veteran_date_of_birth + veteran_address + veteran_home_phone +
        non_veteran_date_of_birth + non_veteran_ssn + non_veteran_phone
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran_full_name', 'first'),
        'veteranLastName' => @data.dig('veteran_full_name', 'last'),
        'fileNumber' => @data.dig('veteran_id', 'va_file_number').presence || @data.dig('veteran_id', 'ssn'),
        'zipCode' => @data.dig('veteran_mailing_address',
                               'postal_code').presence || @data.dig('non_veteran_mailing_address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def notification_first_name
      if data['preparer_type'] == 'veteran'
        data.dig('veteran_full_name', 'first')
      elsif data['preparer_type'] == 'non-veteran'
        data.dig('non_veteran_full_name', 'first')
      else
        data.dig('third_party_full_name', 'first')
      end
    end

    def notification_last_name
      if data['preparer_type'] == 'veteran'
        data.dig('veteran_full_name', 'last')
      elsif data['preparer_type'] == 'non-veteran'
        data.dig('non_veteran_full_name', 'last')
      else
        data.dig('third_party_full_name', 'last')
      end
    end

    def notification_email_address
      return data['point_of_contact_email'] if should_send_to_point_of_contact?

      if data['preparer_type'] == 'veteran'
        data['veteran_email_address']
      elsif data['preparer_type'] == 'non-veteran'
        data['non_veteran_email_address']
      else
        data['third_party_email_address']
      end
    end

    def notification_point_of_contact_name
      data['point_of_contact_name']
    end

    def zip_code_is_us_based
      @data.dig('veteran_mailing_address', 'country') == 'USA' ||
        @data.dig('non_veteran_mailing_address', 'country') == 'USA'
    end

    def desired_stamps
      coords = if %w[veteran non-veteran].include? data['preparer_type']
                 [[50, 685]]
               elsif data['third_party_type'] == 'power-of-attorney'
                 [[50, 440]]
               elsif %w[third-party-veteran third-party-non-veteran].include? data['preparer_type']
                 [[50, 565]]
               end
      [{ coords:, text: data['statement_of_truth_signature'], page: 4 }]
    end

    def submission_date_stamps(timestamp = Time.current)
      [
        {
          coords: [460, 710],
          text: 'Application Submitted:',
          page: 2,
          font_size: 12
        },
        {
          coords: [460, 690],
          text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
          page: 2,
          font_size: 12
        }
      ]
    end

    def track_user_identity(confirmation_number)
      identity = "#{data['preparer_type']} #{data['third_party_type']}"
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('Simple forms api - 20-10207 submission user identity', identity:, confirmation_number:)

      living_situation_data = data['living_situation']
      other_reasons_data = data['other_reasons']
      living_situations = living_situation_data ? living_situation_data.select { |_, v| v }.keys.join(', ') : nil
      other_reasons = other_reasons_data ? other_reasons_data.select { |_, v| v }.keys.join(', ') : nil
      Rails.logger.info('Simple forms api - 20-10207 submission living situations and other reasons for request',
                        living_situations:, other_reasons:)
    end

    def get_attachments
      PersistentAttachment.where(guid: attachment_guids).map(&:to_pdf)
    end

    def should_send_to_point_of_contact?
      preparer_is_not_third_party? && living_situation_is_none?
    end

    private

    def attachment_guids
      doc_types = %w[als_documents financial_hardship_documents medal_award_documents pow_documents
                     terminal_illness_documents vsi_documents]

      doc_types.flat_map { |type| @data[type]&.pluck('confirmation_code') }.compact
    end

    def veteran_ssn
      [
        data.dig('veteran_id', 'ssn')&.[](0..2),
        data.dig('veteran_id', 'ssn')&.[](3..4),
        data.dig('veteran_id', 'ssn')&.[](5..8)
      ]
    end

    def veteran_date_of_birth
      [
        data['veteran_date_of_birth']&.[](0..3),
        data['veteran_date_of_birth']&.[](5..6),
        data['veteran_date_of_birth']&.[](8..9)
      ]
    end

    def veteran_address
      [
        data.dig('veteran_mailing_address', 'postal_code')&.[](0..4),
        data.dig('veteran_mailing_address', 'postal_code')&.[](5..8)
      ]
    end

    def veteran_home_phone
      [
        data['veteran_phone']&.gsub('-', '')&.[](0..2),
        data['veteran_phone']&.gsub('-', '')&.[](3..5),
        data['veteran_phone']&.gsub('-', '')&.[](6..9)
      ]
    end

    def non_veteran_date_of_birth
      [
        data['non_veteran_date_of_birth']&.[](0..3),
        data['non_veteran_date_of_birth']&.[](5..6),
        data['non_veteran_date_of_birth']&.[](8..9)
      ]
    end

    def non_veteran_ssn
      [
        data.dig('non_veteran_ssn', 'ssn')&.[](0..2),
        data.dig('non_veteran_ssn', 'ssn')&.[](3..4),
        data.dig('non_veteran_ssn', 'ssn')&.[](5..8)
      ]
    end

    def non_veteran_phone
      [
        data['non_veteran_phone']&.gsub('-', '')&.[](0..2),
        data['non_veteran_phone']&.gsub('-', '')&.[](3..5),
        data['non_veteran_phone']&.gsub('-', '')&.[](6..9)
      ]
    end

    def preparer_is_not_third_party?
      %w[third-party-veteran third-party-non-veteran].exclude?(data['preparer_type'])
    end

    def living_situation_is_none?
      data.dig('living_situation', 'NONE')
    end
  end
end
