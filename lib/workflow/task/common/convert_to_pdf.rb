# frozen_string_literal: true
require 'workflow/task/shrine_file/base'
require 'vips'
require 'fastimage'

module Workflow::Task::Common
  class ConvertToPdf < Workflow::Task::ShrineFile::Base
    def run
      image = Vips::Image.new_from_file @file.download.path

      Tempfile.create(%w(temp .jpg)) do |jpg|
        image.write_to_file jpg.path
        w,h = FastImage.size jpg.path

        Tempfile.create(%w(temp .pdf)) do |pdf|
          Prawn::Document.generate(pdf.path, page_size: [w,h]) do
            margin = 36 # pdf margin .5 inches (72 pts/in)
            image jpg.path, at: [-margin, h-margin], width: w, height: h
          end
          update_file(io: pdf)
        end
      end
    end
  end
end
