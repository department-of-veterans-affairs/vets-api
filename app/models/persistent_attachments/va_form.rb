# frozen_string_literal: true

class PersistentAttachments::VAForm < PersistentAttachment
  include ::FormUpload::Uploader::Attachment.new(:file)

  before_destroy(:delete_file)

  CONFIGS = Hash.new(
    { max_pages: 10, min_pages: 1 }
  ).merge(
    {
      '21-0779' => { max_pages: 4, min_pages: 2 },
      '21-4192' => { max_pages: 2, min_pages: 2 },
      '21-509' => { max_pages: 4, min_pages: 2 },
      '21-686c' => { max_pages: 16, min_pages: 2 },
      '21-8940' => { max_pages: 4, min_pages: 2 },
      '21P-0516-1' => { max_pages: 2, min_pages: 2 },
      '21P-0517-1' => { max_pages: 2, min_pages: 2 },
      '21P-0518-1' => { max_pages: 2, min_pages: 2 },
      '21P-0519C-1' => { max_pages: 2, min_pages: 2 },
      '21P-0519S-1' => { max_pages: 2, min_pages: 2 },
      '21P-530a' => { max_pages: 2, min_pages: 2 },
      '21P-8049' => { max_pages: 4, min_pages: 4 }
    }
  )

  def max_pages
    CONFIGS[form_id][:max_pages]
  end

  def min_pages
    CONFIGS[form_id][:min_pages]
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
