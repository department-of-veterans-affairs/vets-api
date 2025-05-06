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

        new_file_path = File.join('tmp', new_file_name)

        # Use FileUtils.mv to handle `Errno::EXDEV` error since encrypted PDFs
        # get stashed in the clamav_tmp dir which is a different device on staging, apparently
        Rails.logger.info("IVC ChampVA Forms - Handling attachment #{index} via mv")
        FileUtils.mv(attachment, new_file_path) # Performs a copy automatically if mv fails

        file_paths << new_file_path
      rescue Errno::ENOENT # File.rename and FileUtils.mv throw this error when a file is not found
        # e.message contains a filename which could include PII, so only pass on a hard coded message
        file_processing_errors << "Error processing attachment at index #{index}: ENOENT No such file or directory"
      rescue SystemCallError => e # Base class for any filesystem related errors
        # e.message could contain a filename and PII, so only pass on the decoded error number when available
        error_name = Errno.constants.find(proc {
          "Unknown #{e.errno}"
        }) { |c| Errno.const_get(c).new.errno == e.errno }.to_s
        file_processing_errors << "Error processing attachment at index #{index}: SystemCallError #{error_name}"
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
      # Deep copy @data so we don't clobber the ADDITIONAL_PDF_KEY array:
      additional_form_data = Marshal.load(Marshal.dump(@data))

      additional_form_data[self.class::ADDITIONAL_PDF_KEY] = additional_data
      filler = IvcChampva::PdfFiller.new(
        form_number: form_id,
        form: self.class.name.constantize.new(additional_form_data),
        name: "#{form_id}_additional_#{self.class::ADDITIONAL_PDF_KEY}-#{index}",
        uuid:
      )
      filler.generate
    end
  end
end
