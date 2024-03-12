# frozen_string_literal: true

module SimpleFormsApi
  class VBA2010207
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
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

    def track_user_identity; end

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
