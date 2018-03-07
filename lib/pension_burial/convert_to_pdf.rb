# frozen_string_literal: true


module PensionBurial
  class ConvertToPdf
    def initialize(file)
      @file = file
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def run
      return if @file.content_type == Mime[:pdf].to_s

      unless @file.content_type.starts_with?('image/')
        raise IOError, "PDF conversion failed, unsupported file type: #{@file.content_type}"
      end

      out_file = "#{Common::FileHelpers.random_file_path}.pdf"
      in_file = Common::FileHelpers.generate_temp_file(@file.read)

      MiniMagick::Tool::Convert.new do |convert|
        convert << '-units' << 'pixelsperinch' << '-density' << '72' << '-page' << 'letter'
        convert << in_file
        convert << out_file
      end

      out_file
    ensure
      File.delete(in_file) if defined?(in_file) && in_file.present?
    end
    # rubocop:enable Metrics/CyclomaticComplexity
  end
end
