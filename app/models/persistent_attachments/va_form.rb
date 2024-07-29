# frozen_string_literal: true

class PersistentAttachments::VAForm < PersistentAttachment
  attr_accessor :form_id

  include ::FormUpload::Uploader::Attachment.new(:file)

  before_destroy(:delete_file)

  def max_pages
    configs[form_id][:max_pages]
  end

  def min_pages
    configs[form_id][:min_pages]
  end

  def warnings
    @warnings ||= []
  end

  def as_json(options = {})
    super(options).merge(warnings:)
  end

  private

  def configs
    {
      '21-0779' => {
        max_pages: 4,
        min_pages: 2
      }
    }.tap do |config|
      config.default = { max_pages: 10, min_pages: 1 }
    end
  end

  def delete_file
    file.delete
  end
end
