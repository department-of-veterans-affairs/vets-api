# frozen_string_literal: true

class FormAttachment < ActiveRecord::Base
  include SetGuid

  attr_encrypted(:file_data, key: Settings.db_encryption_key)

  validates(:file_data, :guid, presence: true)

  def set_file_data!(file)
    attachment_uploader = get_attachment_uploader
    attachment_uploader.store!(file)
    self.file_data = { filename: attachment_uploader.filename }.to_json
  end

  def parsed_file_data
    @parsed_file_data ||= JSON.parse(file_data)
  end

  def get_file
    attachment_uploader = get_attachment_uploader
    attachment_uploader.retrieve_from_store!(
      parsed_file_data['filename']
    )
    attachment_uploader.file
  end

  private

  def get_attachment_uploader
    self.class::ATTACHMENT_UPLOADER_CLASS.new(guid)
  end
end
