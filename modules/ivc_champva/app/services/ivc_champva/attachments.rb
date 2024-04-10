# frozen_string_literal: true

module IvcChampva
  module Attachments
    attr_accessor :form_id, :uuid, :data

    def handle_attachments(file_path)
      file_path_uuid = file_path.gsub("#{form_id}-tmp", "#{uuid}_#{form_id}-tmp")
      File.rename(file_path, file_path_uuid)
      attachments = get_attachments
      file_paths = [file_path_uuid]

      if attachments.count.positive?
        attachments.each_with_index do |attachment, index|
          new_file_name = "#{uuid}_#{form_id}-tmp#{index + 1}.pdf"
          new_file_path = File.join(File.dirname(attachment), new_file_name)
          File.rename(attachment, new_file_path)
          file_paths << new_file_path
        end
      end

      file_paths
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
