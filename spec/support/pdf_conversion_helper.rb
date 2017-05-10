# frozen_string_literal: true
module PdfConversionHelper
  def create_jpg(file_path)
    MiniMagick::Tool::Convert.new do |convert|
      convert.size '1024x768'
      convert.gravity 'center'
      convert.xc 'white'
      convert << file_path
    end
  end
end
