# frozen_string_literal: true
module VIC
  class SupportingDocumentationAttachment < FormAttachment
    ATTACHMENT_UPLOADER_CLASS = SupportingDocumentationAttachmentUploader
    PDF_CONTENT_TYPE = 'application/pdf'

    def set_file_data!(file)
      converted_file =
        if MimeMagic.by_magic(file).type == PDF_CONTENT_TYPE
          file
        else
          convert_to_pdf(file)
        end

      super(converted_file)
    end

    def self.combine_documents(guids)
      guids.each do |guid|
        attachment = where(guid: guid).take
      end
    end

    private

    def convert_to_pdf(file)
      new_file_path = "tmp/#{SecureRandom.uuid}.pdf"
      image = MiniMagick::Image.open(file.path)
      image.format('pdf')
      image.write(new_file_path)

      File.open(new_file_path)
    end
  end
end
