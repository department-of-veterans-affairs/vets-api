# frozen_string_literal: true

module ReencodeImages
  extend ActiveSupport::Concern

  included do
    process :reencode
  end

  def reencode
    unless file.content_type == 'application/pdf'
      manipulate! do |img|
        img.format(img.type)
        img
      end
    end
  end
end
