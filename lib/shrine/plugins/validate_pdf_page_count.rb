# frozen_string_literal: true

class Shrine
  module Plugins
    module ValidatePdfPageCount
      module AttacherMethods
        def validate_pdf_page_count(max_pages: nil, min_pages: 1)
          return unless get.mime_type == Mime[:pdf].to_s

          file = get.download
          page_count = get_page_count(file)

          if page_count > max_pages
            record.instance_variable_set(:@too_many_pages, true)
          elsif page_count < min_pages
            record.instance_variable_set(:@too_few_pages, true)
          end
        end

        private

        def get_page_count(file)
          reader = PDF::Reader.new(file)
          reader.page_count
        end
      end
    end

    register_plugin(:validate_pdf_page_count, ValidatePdfPageCount)
  end
end
