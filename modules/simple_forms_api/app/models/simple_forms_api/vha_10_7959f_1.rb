# frozen_string_literal: true

module SimpleFormsApi
  class VHA107959f1
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran', 'full_name', 'first'),
        'veteranLastName' => @data.dig('veteran', 'full_name', 'last'),
        'fileNumber' => @data.dig('veteran', 'va_claim_number').presence || @data.dig('veteran', 'ssn'),
        'zipCode' => @data.dig('veteran', 'mailing_address', 'postal_code') || '00000',
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def zip_code_is_us_based
      # TODO: Implement this
      true
    end

    def desired_stamps
      [{ coords: [26, 82.5], text: data['statement_of_truth_signature'], page: 0 }]
    end

    def submission_date_config
      { should_stamp_date?: false }
    end

    def track_user_identity(confirmation_number); end
  end
end
