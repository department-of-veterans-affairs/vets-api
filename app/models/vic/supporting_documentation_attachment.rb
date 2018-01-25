# frozen_string_literal: true
module VIC
  class SupportingDocumentationAttachment < FormAttachment
    ATTACHMENT_UPLOADER_CLASS = SupportingDocumentationAttachmentUploader
    PDF_CONTENT_TYPE = 'application/pdf'

    def self.get_random_file_path
      "tmp/#{SecureRandom.uuid}.pdf"
    end

    def self.combine_documents(guids)
      final_path = get_random_file_path

      file_paths = guids.map do |guid|
        attachment = where(guid: guid).take
        file_path = get_random_file_path

        File.open(file_path, 'wb') do |file|
          file.write(attachment.get_file.read)
        end

        file_path
      end
      file_paths << final_path

      PdfFill::Filler::PDF_FORMS.cat(*file_paths)
      # TODO clean up files

      final_path
    end

    def set_file_data!(file)
      converted_file =
        if MimeMagic.by_magic(file).type == PDF_CONTENT_TYPE
          file
        else
          convert_to_pdf(file)
        end

      super(converted_file)
      # TODO clean up file
    end

    private

    def convert_to_pdf(file)
      new_file_path = self.class.get_random_file_path
      image = MiniMagick::Image.open(file.path)
      image.format('pdf')
      image.write(new_file_path)

      File.open(new_file_path)
    end
  end
end
