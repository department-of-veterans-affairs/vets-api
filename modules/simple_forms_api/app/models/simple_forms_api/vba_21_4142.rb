# frozen_string_literal: true

module SimpleFormsApi
  class VBA214142
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

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
  end
end
