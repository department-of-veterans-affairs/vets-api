# frozen_string_literal: true

class PersistentAttachments::VAForm < PersistentAttachment
  attr_accessor :form_id

  include ::FormUpload::Uploader::Attachment.new(:file)

  before_destroy(:delete_file)

  def max_pages
    if form_id == '21-0779'
      4
    else
      10
    end
  end

  def min_pages
    if form_id == '21-0779'
      2
    else
      1
    end
  end

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
