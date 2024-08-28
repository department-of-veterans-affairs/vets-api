# frozen_string_literal: true

require 'common/file_helpers'

module Common
  class ConvertToPdf
    def initialize(file)
      @file = file
    end

    def run
      in_file = Common::FileHelpers.generate_clamav_temp_file(@file.read)
      return in_file if @file.content_type == Mime[:pdf].to_s

      unless @file.content_type.starts_with?('image/')
        File.delete(in_file)
        raise IOError, "PDF conversion failed, unsupported file type: #{@file.content_type}"
      end

      out_file = "#{Common::FileHelpers.random_file_path}.pdf"

      begin
        MiniMagick::Tool::Convert.new do |convert|
          convert << '-units' << 'pixelsperinch' << '-density' << '72' << '-page' << 'letter'
          convert << in_file
          convert << out_file
        end
      ensure
        File.delete(in_file)
      end

      out_file
    end
  end
end
