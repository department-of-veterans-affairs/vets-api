# frozen_string_literal: true

module SimpleFormsApi
  class VBA2110210
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

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

    def words_to_remove
      veteran_ssn + veteran_date_of_birth + veteran_mailing_address + veteran_phone + veteran_email +
        claimant_ssn + claimant_date_of_birth + claimant_mailing_address + claimant_phone + claimant_email +
        statement + witness_phone + witness_email
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
