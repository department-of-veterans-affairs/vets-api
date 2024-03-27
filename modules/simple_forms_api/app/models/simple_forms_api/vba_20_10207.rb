# frozen_string_literal: true

module SimpleFormsApi
  class VBA2010207
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

    def currently_homeless?
      (0..2).include? homeless_living_situation
    end

    def homeless_living_situation
      if @data['living_situation']['SHELTER']
        0
      elsif @data['living_situation']['FRIEND_OR_FAMILY']
        1
      elsif @data['living_situation']['OVERNIGHT']
        2
      end
    end

    def at_risk_of_being_homeless?
      (0..2).include? risk_homeless_living_situation
    end

    def risk_homeless_living_situation
      if @data['living_situation']['LOSING_HOME']
        0
      elsif @data['living_situation']['LEAVING_SHELTER']
        1
      elsif @data['living_situation']['OTHER_RISK']
        2
      end
    end

    def facility_name(index)
      facility = @data['medical_treatments']&.[](index - 1)
      "#{facility&.[]('facility_name')}\n#{facility_address(index)}"
    end

    def facility_address(index)
      facility = @data['medical_treatments']&.[](index - 1)
      address = facility&.[]('facility_address')
      "#{address&.[]('street')}\n
        #{address&.[]('city')}, #{address&.[]('state')} #{address&.[]('postal_code')}\n
        #{address&.[]('country')}"
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
      @data['statement_of_truth_signature'] if @data['preparer_type'] == 'veteran'
    end

    def third_party_signature
      @data['statement_of_truth_signature'] if @data['preparer_type'] != 'veteran' &&
                                               @data['third_party_type'] != 'power-of-attorney'
    end

    def power_of_attorney_signature
      @data['statement_of_truth_signature'] if @data['third_party_type'] == 'power-of-attorney'
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran_full_name', 'first'),
        'veteranLastName' => @data.dig('veteran_full_name', 'last'),
        'fileNumber' => @data.dig('veteran_id', 'va_file_number').presence || @data.dig('veteran_id', 'ssn'),
        'zipCode' => @data.dig('veteran_mailing_address', 'postal_code').presence || '00000',
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def handle_attachments(file_path)
      attachments = get_attachments
      if attachments.count.positive?
        combined_pdf = CombinePDF.new
        combined_pdf << CombinePDF.load(file_path)
        attachments.each do |attachment|
          combined_pdf << CombinePDF.load(attachment)
        end

        combined_pdf.save file_path
      end
    end

    def submission_date_config
      {
        should_stamp_date?: false
      }
    end

    def track_user_identity(confirmation_number); end

    private

    def get_attachments
      attachments = []

      financial_hardship_documents = @data['financial_hardship_documents']
      als_documents = @data['als_documents']
      medal_award_documents = @data['medal_award_documents']
      pow_documents = @data['pow_documents']
      terminal_illness_documents = @data['terminal_illness_documents']
      vsi_documents = @data['vsi_documents']

      [
        financial_hardship_documents,
        als_documents,
        medal_award_documents,
        pow_documents,
        terminal_illness_documents,
        vsi_documents
      ].compact.each do |documents|
        confirmation_codes = []
        documents&.map { |doc| confirmation_codes << doc['confirmation_code'] }

        PersistentAttachment.where(guid: confirmation_codes).map { |attachment| attachments << attachment.to_pdf }
      end

      attachments
    end
  end
end
