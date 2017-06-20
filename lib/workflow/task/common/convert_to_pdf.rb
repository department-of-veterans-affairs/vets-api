# frozen_string_literal: true
require 'workflow/task/shrine_file/base'

module Workflow::Task::Common
  class ConvertToPdf < Workflow::Task::ShrineFile::Base
    def run
      unless @file.content_type =~ %r{image\/}
        raise IOError, "PDF conversion failed, unsupported file type: #{@file.content_type}"
      end

      Tempfile.create(%w(temp .pdf)) do |pdf|
        MiniMagick::Tool::Convert.new do |convert|
          convert << @file.download.path
          convert << pdf.path
        end
        update_file(io: pdf)
      end
    end
  end
end
