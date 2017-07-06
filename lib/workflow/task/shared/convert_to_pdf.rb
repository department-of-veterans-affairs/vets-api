# frozen_string_literal: true
require 'workflow/task/shrine_file/base'

module Workflow::Task::Shared
  class ConvertToPdf < Workflow::Task::ShrineFile::Base
    def run
      return if @file.content_type == Mime[:pdf].to_s

      unless @file.content_type.starts_with?('image/')
        raise IOError, "PDF conversion failed, unsupported file type: #{@file.content_type}"
      end

      out_dir = FileUtils.mkdir_p(Rails.root.join('tmp', 'pdfs', SecureRandom.uuid))
      out_file = File.join(out_dir, @file.original_filename + '.pdf')

      MiniMagick::Tool::Convert.new do |convert|
        convert << '-units' << 'pixelsperinch'
        convert << '-density' << '72'
        convert << '-page' << 'letter'
        convert << @file.download.path
        convert << out_file
      end
      update_file(io: File.open(out_file))
    ensure
      FileUtils.rmdir(out_dir) if defined?(out_dir) && out_dir.present?
    end
  end
end
