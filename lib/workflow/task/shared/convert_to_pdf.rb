# frozen_string_literal: true
require 'workflow/task/shrine_file/base'

module Workflow::Task::Shared
  class ConvertToPdf < Workflow::Task::ShrineFile::Base
    def run
      return if @file.content_type == Mime[:pdf].to_s

      unless @file.content_type.starts_with?('image/')
        raise IOError, "PDF conversion failed, unsupported file type: #{@file.content_type}"
      end

      Tempfile.create(%w(temp .pdf)) do |pdf|
        MiniMagick::Tool::Convert.new do |convert|
          convert << @file.download.path
          convert << '-gravity' << 'North'
          convert << '-units' << 'pixelsperinch'
          convert << '-density' << '72'
          convert << '-page' << 'letter'
          convert << pdf.path
        end
        update_file(io: pdf)
      end
    end
  end
end
