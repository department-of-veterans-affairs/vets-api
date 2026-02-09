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
      '21-526EZ' => { max_pages: 15, min_pages: 6 },
      '21-686c' => { max_pages: 16, min_pages: 2 },
      '21-8940' => { max_pages: 4, min_pages: 2 },
      '21P-0516-1' => { max_pages: 2, min_pages: 2 },
      '21P-0517-1' => { max_pages: 2, min_pages: 2 },
      '21P-0518-1' => { max_pages: 2, min_pages: 2 },
      '21P-0519C-1' => { max_pages: 2, min_pages: 2 },
      '21P-0519S-1' => { max_pages: 2, min_pages: 2 },
      '21P-530a' => { max_pages: 2, min_pages: 2 },
      '21P-8049' => { max_pages: 4, min_pages: 4 },
      '21-8951-2' => { max_pages: 3, min_pages: 2 },
      '21-674b' => { max_pages: 2, min_pages: 2 },
      '21-2680' => { max_pages: 4, min_pages: 4 },
      '21-0788' => { max_pages: 2, min_pages: 2 },
      '21-4193' => { max_pages: 3, min_pages: 2 },
      '21P-4718a' => { max_pages: 2, min_pages: 2 },
      '21-4140' => { max_pages: 2, min_pages: 2 },
      '21P-4706c' => { max_pages: 4, min_pages: 4 },
      '21-8960' => { max_pages: 2, min_pages: 2 },
      '21-0304' => { max_pages: 4, min_pages: 3 },
      '21-651' => { max_pages: 1, min_pages: 1 },
      '21P-4185' => { max_pages: 2, min_pages: 2 },
      '21P-535' => { max_pages: 10, min_pages: 8 },
      '40-1330M' => { max_pages: 10, min_pages: 1 }
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
