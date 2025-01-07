# frozen_string_literal: true

module SimpleFormsApi
  class VBA214140 < BaseForm
    def desired_stamps
      []
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('full_name', 'first'),
        'veteranLastName' => @data.dig('full_name', 'last'),
        'fileNumber' => @data['va_file_number'].presence || @data['ssn'],
        'zipCode' => @data.dig('address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def submission_date_stamps(_timestamp)
      []
    end
  end
end
