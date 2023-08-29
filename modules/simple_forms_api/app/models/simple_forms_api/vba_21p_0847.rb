# frozen_string_literal: true

module SimpleFormsApi
  class VBA21p0847
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

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
