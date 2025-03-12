# frozen_string_literal: true

module SimpleFormsApi
  class VBA210966 < BaseForm
    STATS_KEY = 'api.simple_forms_api.21_0966'

    def populate_veteran_data(user)
      @data['veteran_full_name'] ||= {
        'first' => user.first_name,
        'last' => user.last_name
      }
      @data['veteran_mailing_address'] ||= user.address
      @data['veteran_id'] ||= {
        'ssn' => user.ssn
      }
      @data['veteran_date_of_birth'] ||= user.birth_date
      @data['veteran_phone'] ||= user.home_phone
      @data['veteran_email'] ||= user.email

      self
    end

    def words_to_remove
      veteran_ssn + veteran_date_of_birth + veteran_address + veteran_home_phone + veteran_email +
        surviving_dependent_ssn + surviving_dependent_address + surviving_dependent_phone +
        surviving_dependent_email + surviving_dependent_date_of_birth
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran_full_name', 'first'),
        'veteranLastName' => @data.dig('veteran_full_name', 'last'),
        'fileNumber' => @data.dig('veteran_id', 'va_file_number').presence || @data.dig('veteran_id', 'ssn'),
        'zipCode' => @data.dig('veteran_mailing_address', 'postal_code') ||
          @data.dig('surviving_dependent_mailing_address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def notification_first_name
      if data['preparer_identification'] == 'SURVIVING_DEPENDENT'
        data.dig('surviving_dependent_full_name', 'first')
      else
        data.dig('veteran_full_name', 'first')
      end
    end

    def notification_email_address
      if data['preparer_identification'] == 'SURVIVING_DEPENDENT'
        data['surviving_dependent_email']
      else
        data['veteran_email']
      end
    end

    def zip_code_is_us_based
      @data.dig('veteran_mailing_address',
                'country') == 'USA' || @data.dig('surviving_dependent_mailing_address', 'country') == 'USA'
    end

    def relationship_to_veteran_radio
      relationship = @data.dig('relationship_to_veteran', 'relationship_to_veteran')
      ['', 'spouse', 'child'].find_index(relationship) if relationship
    end

    def relationship_to_veteran
      relationship = @data.dig('relationship_to_veteran', 'relationship_to_veteran')
      relationship if %w[parent executor other].include?(relationship)
    end

    def third_party_info
      third_party_preparer_full_name = @data['third_party_preparer_full_name']
      role =
        if @data['third_party_preparer_role'] == 'other'
          @data['other_third_party_preparer_role'] || ''
        else
          roles[@data['third_party_preparer_role']] || ''
        end

      if third_party_preparer_full_name
        "#{
          third_party_preparer_full_name['first'] || ''
        } #{
          third_party_preparer_full_name['middle'] || ''
        } #{
          third_party_preparer_full_name['last'] || ''
        }, #{role}"
      end
    end

    def desired_stamps
      [{ coords: [50, 415], text: data['statement_of_truth_signature'], page: 1 }]
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

    def track_user_identity(confirmation_number)
      identity = data['preparer_identification']
      StatsD.increment("#{STATS_KEY}.#{identity}")
      benefit_types = data['benefit_selection'].map do |benefit_type, is_selected|
        benefit_type if is_selected
      end.compact.join(', ')

      Rails.logger.info('Simple forms api - 21-0966 submission user identity', identity:, benefit_types:,
                                                                               confirmation_number:)
    end

    private

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

    def veteran_email
      [
        data['veteran_email']&.[](20..29),
        data['veteran_email']&.[](0..19)
      ]
    end

    def surviving_dependent_ssn
      [
        data.dig('surviving_dependent_id', 'ssn')&.[](0..2),
        data.dig('surviving_dependent_id', 'ssn')&.[](3..4),
        data.dig('surviving_dependent_id', 'ssn')&.[](5..8)
      ]
    end

    def surviving_dependent_address
      [
        data.dig('surviving_dependent_mailing_address', 'postal_code')&.[](0..4),
        data.dig('surviving_dependent_mailing_address', 'postal_code')&.[](5..8)
      ]
    end

    def surviving_dependent_phone
      [
        data['surviving_dependent_phone']&.gsub('-', '')&.[](0..2),
        data['surviving_dependent_phone']&.gsub('-', '')&.[](3..5),
        data['surviving_dependent_phone']&.gsub('-', '')&.[](6..9)
      ]
    end

    def surviving_dependent_email
      [
        data['surviving_dependent_email']&.[](20..29),
        data['surviving_dependent_email']&.[](0..19)
      ]
    end

    def surviving_dependent_date_of_birth
      [
        data['surviving_dependent_date_of_birth']&.[](0..3),
        data['surviving_dependent_date_of_birth']&.[](5..6),
        data['surviving_dependent_date_of_birth']&.[](8..9)
      ]
    end

    def roles
      {
        'fiduciary' => 'Fiduciary',
        'officer' => 'Veteran Service Officer',
        'alternate' => 'Alternate Signer'
      }
    end
  end
end
