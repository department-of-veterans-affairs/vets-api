# frozen_string_literal: true

module SimpleFormsApi
  class VBA2010207
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

    def requester_signature
      if @data['preparer_type'] == 'veteran'
        @data['statement_of_truth_signature']
      end
    end

    def third_party_signature
      if @data['preparer_type'] != 'veteran' && @data['third_party_type'] != 'power-of-attorney'
        @data['statement_of_truth_signature']
      end
    end

    def power_of_attorney_signature
      if @data['third_party_type'] == 'power-of-attorney'
        @data['statement_of_truth_signature']
      end
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

    def submission_date_config
      {
        should_stamp_date?: false
      }
    end

    def track_user_identity; end
  end
end
