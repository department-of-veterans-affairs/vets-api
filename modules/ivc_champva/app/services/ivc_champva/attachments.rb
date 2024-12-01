# frozen_string_literal: true

module IvcChampva
  module Attachments
    attr_accessor :form_id, :uuid, :data

    def handle_attachments(file_path)
      file_paths = [file_path]
      attachments = get_attachments

      attachments.each_with_index do |attachment, index|
        new_file_name = if attachment.include?('_additional_')
                          "#{uuid}_#{File.basename(attachment,
                                                   '.*')}.pdf"
                        else
                          "#{uuid}_#{form_id}_supporting_doc-#{index}.pdf"
                        end
        new_file_path = File.join(File.dirname(attachment), new_file_name)
        File.rename(attachment, new_file_path)
        file_paths << new_file_path
      end

      file_paths
    end

    private

    def get_attachments
      attachments = []
      if defined?(self.class::ADDITIONAL_PDF_KEY) &&
         defined?(self.class::ADDITIONAL_PDF_COUNT) &&
         @data[self.class::ADDITIONAL_PDF_KEY].is_a?(Array) &&
         @data[self.class::ADDITIONAL_PDF_KEY].count > self.class::ADDITIONAL_PDF_COUNT
        additional_data = @data[self.class::ADDITIONAL_PDF_KEY].drop(self.class::ADDITIONAL_PDF_COUNT)
        additional_data.each_slice(self.class::ADDITIONAL_PDF_COUNT).with_index(1) do |data, index|
          file_path = generate_additional_pdf(data, index)
          attachments << file_path
        end
      end

      supporting_documents = @data['supporting_docs']
      if supporting_documents
        confirmation_codes = []
        supporting_documents&.map { |doc| confirmation_codes << doc['confirmation_code'] }
        PersistentAttachment.where(guid: confirmation_codes).map { |attachment| attachments << attachment.to_pdf }
      end

      attachments
    end

    def generate_additional_pdf(additional_data, index)
      additional_form_data = @data
      additional_form_data[self.class::ADDITIONAL_PDF_KEY] = additional_data
      filler = IvcChampva::PdfFiller.new(
        form_number: form_id,
        form: self.class.name.constantize.new(additional_form_data),
        name: "#{form_id}_additional_#{self.class::ADDITIONAL_PDF_KEY}-#{index}"
      )
      filler.generate
    end
  end
end
