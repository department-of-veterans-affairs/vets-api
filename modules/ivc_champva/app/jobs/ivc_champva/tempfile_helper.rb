# frozen_string_literal: true

module IvcChampva
  class TempfileHelper
    ## Saves the attachment as a temporary file
    # @param [PersistentAttachments::MilitaryRecords] attachment The attachment object containing the file
    # @param [String] form_id The ID of the current form, e.g., 'vha_10_10d' (see FORM_NUMBER_MAP)
    def self.tempfile_from_attachment(attachment, form_id)
      original_filename = if attachment.file.respond_to?(:original_filename)
                            attachment.file.original_filename
                          else
                            File.basename(attachment.file.path)
                          end
      ext = File.extname(original_filename)
      tempfile = Tempfile.new(["#{form_id}_attachment_", ext]) # a timestamp and unique ID are added automatically
      tempfile.binmode
      attachment.file.rewind
      while (chunk = attachment.file.read(8 * 1024))
        tempfile.write(chunk)
      end
      tempfile.flush
      tempfile.rewind
      tempfile
    end
  end
end
