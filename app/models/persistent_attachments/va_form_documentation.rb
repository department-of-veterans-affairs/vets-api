# frozen_string_literal: true

class PersistentAttachments::VAFormDocumentation < PersistentAttachment
  include ::ClaimDocumentation::Uploader::Attachment.new(:file)

  before_destroy(:delete_file)

  def warnings
    @warnings ||= []
  end

  def as_json(options = {})
    super(options).merge(warnings:)
  end

  private

  def delete_file
    file.delete
  end
end
