# frozen_string_literal: true

require 'hexapdf'

class PdfPostProcessor
  def initialize(old_file_path, combined_pdf_path, section_coordinates, placeholder_links)
    @old_file_path = old_file_path
    @combined_pdf_path = combined_pdf_path
    @section_coordinates = section_coordinates
    @placeholder_links = placeholder_links
  end

  def process!
    old_page_count = find_page_count(@old_file_path)
    add_annotations(@combined_pdf_path, @section_coordinates, @placeholder_links, old_page_count)
  end

  def find_page_count(doc_path)
    reader = PDF::Reader.new(doc_path)
    reader.page_count
  end

  def add_annotations(doc_path, section_coordinates, placeholder_links, original_page_count)
    doc = HexaPDF::Document.open(doc_path)
    main_form_destinations = prepare_destinations_to_main_form(doc)
    overflow_form_destinations = prepare_destinations_to_overflow_form(doc, section_coordinates, original_page_count)
    all_destinations = main_form_destinations + overflow_form_destinations
    add_text_styling(doc, placeholder_links)
    add_all_destinations(doc, all_destinations)
    add_links(doc, section_coordinates, original_page_count)

    add_links(doc, placeholder_links, original_page_count)

    doc.write(doc_path)
    doc_path
  end

  def prepare_destinations_to_main_form(doc)
    form_class = PdfFill::Forms::Va210781v2

    main_form_destinations = []
    form_class::SECTIONS.each do |section|
      page = section[:page] - 1
      x = 0
      y = section[:dest_y_coord]
      dest_name = section[:dest_name]
      dest = doc.wrap([doc.pages[page], :XYZ, x, y, nil])
      main_form_destinations << dest_name
      main_form_destinations << dest
    end
    main_form_destinations
  end

  def prepare_destinations_to_overflow_form(doc, section_coordinates, original_page_count)
    dest_padding = 20
    if section_coordinates
      overflow_form_destinations = []
      section_coordinates.each do |coord|
        page = coord[:page] + original_page_count - 1
        dest_name = "overflow_section_#{coord[:section_label]}"
        dest = doc.wrap([doc.pages[page], :XYZ, coord[:x] + dest_padding, coord[:y] + dest_padding, nil])
        overflow_form_destinations << dest_name
        overflow_form_destinations << dest
      end
      overflow_form_destinations
    end
  end

  def prepare_link(coord, doc, original_page_count)
    # This is a way to determine correct page the link. This can be improved, but for now it checks the name of a key i
    # in the object to determine if it should add 1 or not.
    coord[:dest] ? doc.pages[coord[:page] + original_page_count - 1] : doc.pages[coord[:page]]
  end

  def add_links(doc, section_coordinates, original_page_count)
    section_coordinates.each do |coord|
      page = prepare_link(coord, doc, original_page_count)
      next unless page

      page[:Annots] ||= []
      page[:Annots] << create_link(doc, coord)
    end
  end

  def add_text_styling(doc, placeholder_links)
    return unless placeholder_links

    placeholder_links.each do |link_info|
      page = doc.pages[link_info[:page]]
      canvas = page.canvas(type: :overlay)
      add_white_rectangle(canvas, link_info)
      add_overlay_text(canvas, link_info)
    end
  end

  def add_white_rectangle(canvas, link_info)
    canvas.save_graphics_state do
      canvas.fill_color('FFFFFF')
      canvas.rectangle(link_info[:x], link_info[:y] + 3, link_info[:width], 15)
      canvas.fill
    end
  end

  def add_overlay_text(canvas, link_info)
    y_offset = 8
    x_offset = 3
    canvas.save_graphics_state do
      canvas.stroke_color('0000FF')
      canvas.fill_color('0000FF')
      canvas.font('Helvetica', size: 10)
      text = 'See attachment'
      text_width = 70
      canvas.text(text, at: [link_info[:x] + x_offset, link_info[:y] + y_offset])
      underline_y = (link_info[:y] + y_offset) - 1
      canvas.line(link_info[:x] + x_offset, underline_y, link_info[:x] + text_width + x_offset, underline_y)
      canvas.stroke
    end
  end

  def add_all_destinations(doc, destination_array)
    doc.catalog[:Names] ||= doc.wrap({})
    doc.catalog[:Names][:Dests] = doc.add({ Names: destination_array })
  end

  def create_link(doc, coord)
    destination = coord[:dest] || coord[:dest_name]
    doc.add({
              Type: :Annot,
              Subtype: :Link,
              Rect: [coord[:x], coord[:y], coord[:x] + coord[:width], coord[:y] + coord[:height]],
              Border: [0, 0, 0],
              A: {
                Type: :Action,
                S: :GoTo,
                D: destination
              }
            })
  end
end
