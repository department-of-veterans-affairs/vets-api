# frozen_string_literal: true

module IvcChampva
  module Attachments
    attr_accessor :form_id, :uuid, :data

    def handle_attachments(file_path) # rubocop:disable Metrics/MethodLength
      file_paths = [file_path]
      file_processing_errors = []

      Rails.logger.info('IVC ChampVA Forms - Getting attachments')
      attachments = get_attachments

      Rails.logger.info("IVC ChampVA Forms - Processing #{attachments.size} attachments for form #{form_id} #{uuid}")
      attachments.each_with_index do |attachment, index|
        new_file_name = if attachment.include?('_additional_')
                          Rails.logger.info("IVC ChampVA Forms - Attachment #{index} is additional")
                          "#{uuid}_#{File.basename(attachment,
                                                   '.*')}.pdf"
                        else
                          Rails.logger.info("IVC ChampVA Forms - Attachment #{index} is supporting")
                          "#{uuid}_#{form_id}_supporting_doc-#{index}.pdf"
                        end

        new_file_path = if Flipper.enabled?(:champva_pdf_decrypt, @current_user)
                          Rails.logger.info("IVC ChampVA Forms - Attachment #{index} is using decrypt path")
                          File.join('tmp', new_file_name)
                        else
                          Rails.logger.info("IVC ChampVA Forms - Attachment #{index} is using original path")
                          File.join(File.dirname(attachment), new_file_name)
                        end

        if Flipper.enabled?(:champva_pdf_decrypt, @current_user)
          # Use FileUtils.mv to handle `Errno::EXDEV` error since encrypted PDFs
          # get stashed in the clamav_tmp dir which is a different device on staging, apparently
          Rails.logger.info("IVC ChampVA Forms - Handling attachment #{index} via mv")
          FileUtils.mv(attachment, new_file_path) # Performs a copy automatically if mv fails
        else
          Rails.logger.info("IVC ChampVA Forms - Handling attachment #{index} via rename")
          File.rename(attachment, new_file_path)
        end

        file_paths << new_file_path
      rescue => e
        file_processing_errors << "Error processing attachment at index #{index}: #{e.message}"
      end

      unless file_processing_errors.empty?
        error_message = "Unable to process all attachments: #{file_processing_errors.join(', ')}"
        Rails.logger.error("IVC ChampVA Forms - #{error_message}")
        raise StandardError, error_message
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
        # Ensure we create the PDFs in the same order the attachments were uploaded
        PersistentAttachment.where(guid: confirmation_codes)
                            &.sort_by { |pa| pa[:created_at] }
                            &.map { |attachment| attachments << attachment.to_pdf }
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
