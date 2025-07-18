# frozen_string_literal: true

require 'hexapdf'

module PdfFill
  class PdfPostProcessor
    def initialize(old_file_path, combined_pdf_path, section_coordinates, form_class)
      @old_file_path = old_file_path
      @combined_pdf_path = combined_pdf_path
      @section_coordinates = section_coordinates
      @form_class = form_class
    end

    def process!
      old_page_count = find_page_count(@old_file_path)
      add_annotations(@combined_pdf_path, @section_coordinates, old_page_count)
    end

    def find_page_count(doc_path)
      reader = PDF::Reader.new(doc_path)
      reader.page_count
    end

    def add_annotations(doc_path, section_coordinates, original_page_count)
      doc = HexaPDF::Document.open(doc_path)
      add_destinations(doc, @form_class)
      add_links(doc, section_coordinates, original_page_count)

      doc.write(doc_path)
      doc_path
    end

    def add_destinations(doc, form_class)
      names_array = []
      form_class::SECTIONS.each do |section|
        page = section[:page] - 1
        x = 0
        y = section[:dest_y_coord]
        dest_name = section[:dest_name]
        dest = doc.wrap([doc.pages[page], :XYZ, x, y, nil])
        names_array << dest_name
        names_array << dest
      end
      doc.catalog[:Names] ||= doc.wrap({})
      doc.catalog[:Names][:Dests] = doc.add({ Names: names_array })
    end

    def create_link(doc, coord)
      doc.add({
                Type: :Annot,
                Subtype: :Link,
                Rect: [coord[:x], coord[:y], coord[:x] + coord[:width], coord[:y] + coord[:height]],
                Border: [0, 0, 0],
                A: {
                  Type: :Action,
                  S: :GoTo,
                  D: coord[:dest]
                }
              })
    end

    def add_links(doc, section_coordinates, original_page_count)
      section_coordinates.each do |coord|
        page = doc.pages[coord[:page] + original_page_count - 1] # coord[:page] is 1-based, convert to 0-based index
        next unless page

        page[:Annots] ||= []
        page[:Annots] << create_link(doc, coord)
      end
    end
  end
end
