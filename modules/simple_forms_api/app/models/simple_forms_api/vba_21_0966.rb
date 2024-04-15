# frozen_string_literal: true

module SimpleFormsApi
  class VBA210966
    include Virtus.model(nullify_blank: true)
    STATS_KEY = 'api.simple_forms_api.21_0966'

    attribute :data

    def initialize(data)
      @data = data
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

    def submission_date_config
      {
        should_stamp_date?: true,
        page_number: 0,
        title_coords: [460, 710],
        text_coords: [460, 690]
      }
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

    def roles
      {
        'fiduciary' => 'Fiduciary',
        'officer' => 'Veteran Service Officer',
        'alternate' => 'Alternate Signer'
      }
    end
  end
end
