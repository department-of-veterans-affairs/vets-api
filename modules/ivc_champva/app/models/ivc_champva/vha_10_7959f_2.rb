# frozen_string_literal: true

module IvcChampva
  class VHA107959f2
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
      @uuid = SecureRandom.uuid
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran', 'full_name', 'first'),
        'veteranMiddleName' => @data.dig('veteran', 'full_name', 'middle'),
        'veteranLastName' => @data.dig('veteran', 'full_name', 'last'),
        'fileNumber' => @data.dig('veteran', 'va_claim_number').presence || @data.dig('veteran', 'ssn'),
        'zipCode' => @data.dig('veteran', 'mailing_address', 'postal_code') || '00000',
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP',
        'uuid' => @uuid
      }
    end

    def handle_attachments(file_path)
      uuid = @uuid # Generate the UUID as an instance variable
      file_path_uuid = file_path.gsub('vha_10_7959f_2-tmp', "#{uuid}_vha_10_7959f_2-tmp")
      File.rename(file_path, file_path_uuid)
      attachments = get_attachments
      file_paths = [file_path_uuid]

      if attachments.count.positive?
        attachments.each_with_index do |attachment, index|
          new_file_name = "#{uuid}_vha_10_7959f_2-tmp#{index + 1}.pdf"
          new_file_path = File.join(File.dirname(attachment), new_file_name)
          File.rename(attachment, new_file_path)
          file_paths << new_file_path
        end
      end

      file_paths
    end

    def submission_date_config
      { should_stamp_date?: false }
    end

    def method_missing(_, *args, _)
      args
    end

    def respond_to_missing?(method)
      method == :handle_attachments || super
    end

    private

    def get_attachments
      attachments = []

      supporting_documents = @data['supporting_docs']
      if supporting_documents
        confirmation_codes = []
        supporting_documents&.map { |doc| confirmation_codes << doc['confirmation_code'] }
        PersistentAttachment.where(guid: confirmation_codes).map { |attachment| attachments << attachment.to_pdf }
      end

      attachments
    end
  end
end
