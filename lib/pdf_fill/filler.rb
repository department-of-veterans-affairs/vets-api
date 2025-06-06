# frozen_string_literal: true

require 'pdf_fill/extras_generator'
require 'pdf_fill/extras_generator_v2'
require 'pdf_fill/forms/va214142'
require 'pdf_fill/forms/va210781a'
require 'pdf_fill/forms/va210781'
require 'pdf_fill/forms/va210781v2'
require 'pdf_fill/forms/va218940'
require 'pdf_fill/forms/va1010cg'
require 'pdf_fill/forms/va1010ez'
require 'pdf_fill/forms/va686c674'
require 'pdf_fill/forms/va686c674v2'
require 'pdf_fill/forms/va281900'
require 'pdf_fill/forms/va288832'
require 'pdf_fill/forms/va21674'
require 'pdf_fill/forms/va21674v2'
require 'pdf_fill/forms/va210538'
require 'pdf_fill/forms/va261880'
require 'pdf_fill/forms/va5655'
require 'pdf_fill/forms/va2210216'
require 'pdf_fill/forms/va2210215'
require 'utilities/date_parser'
require 'pdf_fill/pdf_post_processor'

# rubocop:disable Metrics/ModuleLength
module PdfFill
  # Provides functionality to fill and process PDF forms.
  #
  # This module includes methods to register form classes, fill out PDF forms, and handle extra PDF generation.
  module Filler
    class PdfFillerException < StandardError; end
    module_function

    # A PdfForms instance for handling standard PDF forms.
    PDF_FORMS = PdfForms.new(Settings.binaries.pdftk)

    # A PdfForms instance for handling Unicode PDF forms with XFdf data format.
    UNICODE_PDF_FORMS = PdfForms.new(Settings.binaries.pdftk, data_format: 'XFdf', utf8_fields: true)

    # A hash mapping form IDs to their corresponding form classes.
    # This constant is intentionally mutable.
    FORM_CLASSES = {} # rubocop:disable Style/MutableConstant

    ##
    # Registers a form class with a specific form ID.
    #
    # @param form_id [String] The form ID to register.
    # @param form_class [Class] The class associated with the form ID.
    #
    def register_form(form_id, form_class)
      FORM_CLASSES[form_id] = form_class
    end

    # Registers form classes for various form IDs.
    {
      '21-4142' => PdfFill::Forms::Va214142,
      '21-0781a' => PdfFill::Forms::Va210781a,
      '21-0781' => PdfFill::Forms::Va210781,
      '21-0781V2' => PdfFill::Forms::Va210781v2,
      '21-8940' => PdfFill::Forms::Va218940,
      '10-10CG' => PdfFill::Forms::Va1010cg,
      '10-10EZ' => PdfFill::Forms::Va1010ez,
      '686C-674' => PdfFill::Forms::Va686c674,
      '686C-674-V2' => PdfFill::Forms::Va686c674v2,
      '28-1900' => PdfFill::Forms::Va281900,
      '28-8832' => PdfFill::Forms::Va288832,
      '21-674' => PdfFill::Forms::Va21674,
      '21-674-V2' => PdfFill::Forms::Va21674v2,
      '21-0538' => PdfFill::Forms::Va210538,
      '26-1880' => PdfFill::Forms::Va261880,
      '5655' => PdfFill::Forms::Va5655,
      '22-10216' => PdfFill::Forms::Va2210216,
      '22-10215' => PdfFill::Forms::Va2210215
    }.each do |form_id, form_class|
      register_form(form_id, form_class)
    end

    ##
    # Combines extra pages into the main PDF if necessary.
    #
    # @param old_file_path [String] The path to the original PDF file.
    # @param extras_generator [ExtrasGenerator] The generator for extra pages.
    #
    # @return [String] The path to the final combined PDF.
    #
    def combine_extras(old_file_path, extras_generator, hash_converter = nil)
      require 'hexapdf'
      if extras_generator.text?
        file_path = "#{old_file_path.gsub('.pdf', '')}_final.pdf"
        extras_path = extras_generator.generate

        main_reader = PDF::Reader.new(old_file_path)
        original_page_count = main_reader.page_count

        PDF_FORMS.cat(old_file_path, extras_path, file_path)

        add_annotations(file_path, extras_generator, original_page_count, hash_converter)

        # Adds links and destintions to the combined PDF
        pdf_post_processor = PdfPostProcessor.new(old_file_path, file_path, extras_generator.section_coordinates)
        pdf_post_processor.process!


        File.delete(extras_path)
        File.delete(old_file_path)

        file_path
      else
        old_file_path
      end
    end


    def add_annotations(doc_path, extras_generator, original_page_count, hash_converter = nil)
      doc = HexaPDF::Document.open(doc_path)
      main_form_destinations = prepare_destinations_to_main_form(doc)
      overflow_form_destinations = prepare_destinations_to_overflow_form(doc, extras_generator, original_page_count)
      all_destinations = main_form_destinations + overflow_form_destinations
      add_text_styling(doc, hash_converter)
      add_all_destinations(doc, all_destinations)
      add_links(doc, extras_generator, original_page_count)

      # Add placeholder links if hash_converter is provided
      add_links_for_overflow_content(doc, hash_converter) if hash_converter

      doc.write(doc_path)
      doc_path
    end

    def add_text_styling(doc, hash_converter)
      return unless hash_converter.respond_to?(:placeholder_links)

      hash_converter.placeholder_links.each do |link_info|
        page = doc.pages[link_info[:page]]
        canvas = page.canvas(type: :overlay)
        add_white_rectangle(canvas,link_info)
        add_overlay_text(canvas, link_info)
      end
    end

    def add_white_rectangle(canvas, link_info)
      canvas.save_graphics_state do
        canvas.fill_color("FFFFFF")
        canvas.rectangle(link_info[:x], link_info[:y]+3, link_info[:width], 15)
        canvas.fill
      end
    end

    def add_overlay_text(canvas, link_info)
      y_offset = 8
      x_offset = 3
      canvas.save_graphics_state do
        canvas.stroke_color("0000FF")
          canvas.fill_color("0000FF")
          canvas.font("Helvetica", size: 10)
          text = 'See attachment'
          text_width = 70
          canvas.text(text, at: [link_info[:x] + x_offset, link_info[:y] + y_offset])
          underline_y = (link_info[:y] + y_offset) -1
          canvas.line(link_info[:x] + x_offset, underline_y, link_info[:x] + text_width + x_offset, underline_y)
          canvas.stroke
      end
    end

    def add_all_destinations(doc, destination_array)
      doc.catalog[:Names] ||= doc.wrap({})
      doc.catalog[:Names][:Dests] = doc.add({ Names: destination_array })
    end

    def prepare_destinations_to_main_form(doc)
      form_class = PdfFill::Forms::Va210781v2

      main_form_destinations = []
      form_class::SECTIONS.each do |section|
        page = section[:page] - 1
        x = 0
        y = section[:dest_y_coord]
        dest_name = section[:dest_name]
        dest = doc.wrap([doc.pages[page], :XYZ, x, y, nil]) # doc.pages[page] is 0-based index
        main_form_destinations << dest_name
        main_form_destinations << dest
      end
      # doc.catalog[:Names] ||= doc.wrap({})
      # doc.catalog[:Names][:Dests] = doc.add({ Names: names_array })
      main_form_destinations
    end

    def prepare_destinations_to_overflow_form(doc, extras_generator, original_page_count)
      dest_padding = 20
      if extras_generator.respond_to?(:section_coordinates)
        overflow_form_destinations = []
        extras_generator.section_coordinates.each do |coord|
          page = coord[:page] + original_page_count - 1
          dest_name = "overflow_section_#{coord[:section_label]}"
          dest = doc.wrap([doc.pages[page], :XYZ, coord[:x] + dest_padding, coord[:y] + dest_padding, nil])
          overflow_form_destinations << dest_name
          overflow_form_destinations << dest
        end
        # doc.catalog[:Names] ||= doc.wrap({})
        # doc.catalog[:Names][:Dests] = doc.add({ Names: names_array })
        overflow_form_destinations
      end
    end

    def prepare_link(coord, doc, original_page_count)
      coord[:page] # gets the correct overflow page based on main doc length
      doc.pages[coord[:page] + original_page_count - 1] # coord[:page] is 1-based, convert to 0-based index
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

    def add_links(doc, extras_generator, original_page_count)
      if extras_generator.respond_to?(:section_coordinates)
        extras_generator.section_coordinates.each do |coord|
          page = prepare_link(coord, doc, original_page_count)
          next unless page # Skip if page doesn't exist

          page[:Annots] ||= []
          page[:Annots] << create_link(doc, coord)
        end
      end
    end

    def create_placeholder_link(doc, field_coords, dest_name)
      doc.add({
                Type: :Annot,
                Subtype: :Link,
                Rect: [
                  field_coords[:x],
                  field_coords[:y],
                  field_coords[:x] + field_coords[:width],
                  field_coords[:y] + field_coords[:height]
                ],
                Border: [0, 0, 0], # No border
                C: [0, 0, 0], # Blue color
                A: {
                  Type: :Action,
                  S: :GoTo,
                  D: dest_name
                }
              })
    end

    def add_links_for_overflow_content(doc, hash_converter)
      return unless hash_converter.respond_to?(:placeholder_links)

      hash_converter.placeholder_links.each do |link_info|
        field_coords = get_field_coordinates(doc, link_info)
        next unless field_coords

        page = doc.pages[field_coords[:page]]
        next unless page

        page[:Annots] ||= []

        # Add the clickable link
        page[:Annots] << create_placeholder_link(doc, field_coords, link_info[:dest_name])
      end
    end

    def get_field_coordinates(_doc, link_info)
      {
        page: link_info[:page], # Assuming first page for demo
        x: link_info[:x], # These would need to be real coordinates
        y: link_info[:y],
        width: link_info[:width],
        height: 20
      }
    end


    ##
    # Fills a form based on the provided saved claim and options.
    #
    # @param saved_claim [SavedClaim] The saved claim containing form data.
    # @param file_name_extension [String, nil] Optional file name extension.
    # @param fill_options [Hash] Options for filling the form.
    #
    # @raise [PdfFillerException] If the form is not found.
    # @return [String] The path to the filled PDF form.
    #
    def fill_form(saved_claim, file_name_extension = nil, fill_options = {})
      form_id = saved_claim.form_id
      form_class = FORM_CLASSES[form_id]

      raise PdfFillerException, "Form #{form_id} was not found." unless form_class

      process_form(form_id, saved_claim.parsed_form, form_class, file_name_extension || saved_claim.id, fill_options)
    end

    ##
    # Fills an ancillary form based on the provided data and form ID.
    #
    # @param form_data [Hash] The data to fill in the form.
    # @param claim_id [String] The ID of the claim.
    # @param form_id [String] The form ID.
    #
    # @return [String] The path to the filled PDF form.
    #
    def fill_ancillary_form(form_data, claim_id, form_id, fill_options = {})
      process_form(form_id, form_data, FORM_CLASSES[form_id], claim_id, fill_options)
    end

    ##
    # Processes a form by filling it with data and saving it to a file.
    #
    # @param form_id [String] The form ID.
    # @param form_data [Hash] The data to fill in the form.
    # @param form_class [Class] The class associated with the form ID.
    # @param file_name_extension [String] The file name extension for the output PDF.
    # @param fill_options [Hash] Options for filling the form.
    #
    # @return [String] The path to the filled PDF form.
    #
    # rubocop:disable Metrics/MethodLength
    def process_form(form_id, form_data, form_class, file_name_extension, fill_options = {})
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/#{form_id}_#{file_name_extension}.pdf"
      merged_form_data = form_class.new(form_data).merge_fields(fill_options)
      submit_date = Utilities::DateParser.parse(
        merged_form_data['signatureDate'] || fill_options[:created_at] || Time.now.utc
      )

      hash_converter = make_hash_converter(form_id, form_class, submit_date, fill_options)
      new_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: form_class::KEY)
      has_template = form_class.const_defined?(:TEMPLATE)
      template_path = has_template ? form_class::TEMPLATE : "lib/pdf_fill/forms/pdfs/#{form_id}.pdf"
      unicode_pdf_form_list = [SavedClaim::CaregiversAssistanceClaim::FORM,
                               EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781V2]
      (form_id.in?(unicode_pdf_form_list) ? UNICODE_PDF_FORMS : PDF_FORMS).fill_form(
        template_path, file_path, new_hash, flatten: Rails.env.production?
      )

      # If the form is being generated with the overflow redesign, stamp the top and bottom of the document before the
      # form is combined with the extras overflow pages. This allows the stamps to be placed correctly for the redesign
      # implemented in lib/pdf_fill/extras_generator_v2.rb.
      if fill_options.fetch(:extras_redesign, false) && submit_date.present?
        file_path = stamp_form(file_path, submit_date)
      end
      output = combine_extras(file_path, hash_converter.extras_generator, hash_converter)
      Rails.logger.info('PdfFill done', fill_options.merge(form_id:, file_name_extension:, extras: output != file_path))
      output
    end
    # rubocop:enable Metrics/MethodLength

    def make_hash_converter(form_id, form_class, submit_date, fill_options)
      extras_generator =
        if fill_options.fetch(:extras_redesign, false)
          ExtrasGeneratorV2.new(
            form_name: form_id.sub(/V2\z/, ''),
            submit_date:,
            question_key: form_class::QUESTION_KEY,
            start_page: form_class::START_PAGE,
            sections: form_class::SECTIONS,
            label_width: form_class::DEFAULT_LABEL_WIDTH
          )
        else
          ExtrasGenerator.new
        end
      HashConverter.new(form_class.date_strftime, extras_generator)
    end

    def stamp_form(file_path, submit_date)
      original_path = file_path
      sig = "Signed electronically and submitted via VA.gov at #{format_timestamp(submit_date)}. " \
            'Signee signed with an identity-verified account.'
      initial_stamp_path = PDFUtilities::DatestampPdf.new(file_path).run(
        text: sig, x: 5, y: 5, text_only: true, size: 9
      )
      file_path = initial_stamp_path
      file_path = PDFUtilities::DatestampPdf.new(initial_stamp_path).run(
        text: 'VA.gov Submission', x: 510, y: 775, text_only: true, size: 9
      )
      file_path
    rescue => e
      Rails.logger.error("Error stamping form for PdfFill: #{file_path}, error: #{e.message}")
      original_path
    ensure
      File.delete(initial_stamp_path) if initial_stamp_path
    end

    # Formats the timestamp for the PDF footer
    def format_timestamp(datetime)
      return nil if datetime.blank?

      "#{datetime.utc.strftime('%H:%M')} UTC #{datetime.utc.strftime('%Y-%m-%d')}"
    end
  end
end
# rubocop:enable Metrics/ModuleLength
