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

  def too_many_pages
    @too_many_pages || false
  end

  def too_few_pages
    @too_few_pages || false
  end

  def as_json(options = {})
    super(options).merge(too_many_pages:, too_few_pages:)
  end

  private

  def delete_file
    file.delete
  end
end
