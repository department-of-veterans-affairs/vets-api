# frozen_string_literal: true

require 'pdf_fill/filler'

module RepresentationManagement
  module V0
    module PdfConstructor
      class Base
        def initialize(tempfile)
          @tempfile = tempfile
          @template_path = nil
        end

        #
        # This method is the entry point for constructing a pdf.  It will
        # set the template path defined by the subclass, fill in the pdf
        # template, create the next steps page if needed, and combine the
        # pages into a final pdf.
        #
        # The flatten option determines if the pdf is editable or not. It is only true for testing.
        # We enable it in testing to compare the field values of the pdf, specifically the checkbox values.
        #
        # @param data [Hash] Data to fill in pdf form with
        # @param flatten [Boolean] True if the pdf should be flattened. Default is true. False is only used for testing.
        #
        def construct(data, flatten: true)
          set_template_path
          fill_and_combine_pdf(data, flatten:)
        end

        protected

        # @return [String] Path to page 1 pdf template file
        def template_path
          raise 'NotImplemented' # Extend this class and implement
        end

        # @param data [Hash] Data to fill in pdf form
        #
        # @return [Hash] Data to fill in first page of pdf form
        def template_options(_data)
          raise 'NotImplemented' # Extend this class and implement
        end

        #
        # Set the template path that is defined by the subclass
        #
        # @param data [Hash] Hash of data to add to the pdf
        def set_template_path
          @template_path = template_path
        end

        #
        # Determine if the next steps page should be included in the pdf
        #
        # @return [Boolean] True if the next steps page should be included
        def next_steps_page?
          raise 'NotImplemented' # Extend this class and implement
        end

        #
        # Add the contact information to the next steps page
        #
        # @param pdf [Prawn::Document] The pdf to add the contact information to
        def next_steps_contact(_pdf, _data)
          raise 'NotImplemented' # Extend this class and implement
        end

        def next_steps_part1(_pdf)
          raise 'NotImplemented' # Extend this class and implement
        end

        def next_steps_part2(pdf)
          pdf.move_down(30)
          str = <<~HEREDOC.squish
            After your form is signed, you or the accredited representative
            can submit it online, by mail, or in person.
          HEREDOC
          add_text_with_spacing(pdf, str, font: 'soursesanspro')
          add_text_with_spacing(pdf, 'After you submit your printed form', size: 16, style: :bold)
        end

        def next_steps_part3(pdf)
          str = <<~HEREDOC.squish
            We usually process your form within 1 week. You can contact the accredited representative any time.
          HEREDOC
          add_text_with_spacing(pdf, str, font: 'soursesanspro')
          add_text_with_spacing(pdf, 'Need help?', size: 14, style: :bold)
          add_text_with_spacing(pdf, "You can call us at 800-698-2411, ext. 0 (TTY: 711). We're here 24/7.",
                                font: 'soursesanspro')
        end

        private

        # Adds text to the PDF with specified spacing and formatting options.
        #
        # @param pdf [PDF::Document] The PDF document to add the text to.
        # @param text [String] The text to be added.
        # @param options [Hash] (optional) The formatting options for the text.
        # @option options [Integer] :size (12) The font size of the text.
        # @option options [Integer] :move_down (10) The amount of vertical spacing to move down after adding the text.
        # @option options [Symbol] :style (:normal) The font style of the text.
        # @option options [String] :font ('bitter') The font family of the text.
        # @return [void]
        def add_text_with_spacing(pdf, text, options = {})
          size = options.fetch(:size, 12)
          move_down = options.fetch(:move_down, 10)
          style = options.fetch(:style, :normal)
          font = options.fetch(:font, 'bitter')

          pdf.font(font, style:) do
            pdf.font_size(size)
            pdf.text(text)
            pdf.move_down(move_down)
          end
          pdf.font_size(12) # Reset to default size
        end

        # Formats a phone number by removing non-digit characters and adding dashes.
        #
        # @param phone_number [String] The phone number to be formatted.
        # @return [String] The formatted phone number.
        def format_phone_number(phone_number)
          return '' if phone_number.blank?

          phone_number = phone_number.gsub(/\D/, '')
          return phone_number if phone_number.length < 10

          "#{phone_number[0..2]}-#{phone_number[3..5]}-#{phone_number[6..9]}"
        end

        # Removes non-digit characters from a phone number.
        #
        # @param phone_number [String] The phone number to be unformatted.
        # @return [String] The unformatted phone number.
        def unformat_phone_number(phone_number)
          phone_number&.gsub(/\D/, '')
        end

        #
        # Fill in pdf form fields based on data provided, then combine all
        # the pages into a final pdf.  We create an inner tempfile to fill
        # and the output from this method is written to a tempfile in
        # the controller.  Start with a Next Steps page if needed.
        #
        # The flatten option determines if the pdf is editable or not. It is only true for testing.
        # We enable it in testing to compare the field values of the pdf, specifically the checkbox values.
        #
        # @param data [Hash] Data to fill in pdf form with
        # @param flatten [Boolean] True if the pdf should be flattened. Default is true. False is only used for testing.
        #
        def fill_and_combine_pdf(data, flatten: true)
          pdftk = PdfForms.new(Settings.binaries.pdftk)
          template_tempfile = fill_template_form(pdftk, data, flatten:)
          # Only combine PDFs if needed.  Otherwise directly write the template to the output tempfile.
          if next_steps_page?
            next_steps_tempfile = generate_next_steps_page(data)
            combine_pdfs(next_steps_tempfile, template_tempfile)
          else
            FileUtils.copy_file(template_tempfile.path, @tempfile.path)
            @tempfile.rewind
          end

          cleanup_tempfiles(template_tempfile, next_steps_tempfile)
        end

        def generate_next_steps_page(data)
          tempfile = Tempfile.new
          next_steps = Prawn::Document.new
          update_font_families(next_steps)
          next_steps_part1(next_steps)
          next_steps_contact(next_steps, data)
          next_steps_part2(next_steps)
          next_steps_part3(next_steps)
          next_steps.render_file(tempfile.path)
          tempfile
        end

        def update_font_families(document)
          document.font_families.update(
            'bitter' => {
              normal: { file: font_path('bitter-regular.ttf'), subset: false },
              bold: { file: font_path('bitter-bold.ttf'), subset: false }
            },
            'soursesanspro' => {
              normal: { file: font_path('sourcesanspro-regular-webfont.ttf'), subset: false }
            }
          )
        end

        def font_path(filename)
          Rails.root.join('modules', 'representation_management', 'lib', 'fonts', filename)
        end

        #
        # Fill in the PDF template with the data provided.  We create a tempfile during this process to ensure no
        # data remains on the server after the pdf is created.
        #
        # The flatten option determines if the pdf is editable or not. It is only true for testing.
        # We enable it in testing to compare the field values of the pdf, specifically the checkbox values.
        #
        # @param pdftk [PdfForms] The pdftk object to fill in the pdf form
        # @param data [Hash] Data to fill in pdf form with
        # @param flatten [Boolean] True if the pdf should be flattened. Default is true. False is only used for testing.
        #
        def fill_template_form(pdftk, data, flatten: true)
          tempfile = Tempfile.new
          # This is the point where the flatten option is actually used, not just passed down the method chain.
          pdftk.fill_form(@template_path, tempfile.path, template_options(data), flatten:)
          @template_path = tempfile.path
          tempfile.rewind
          tempfile
        end

        def combine_pdfs(next_steps_tempfile, template_tempfile)
          pdf = HexaPDF::Document.new
          next_steps_pdf = HexaPDF::Document.open(next_steps_tempfile.path)
          next_steps_pdf.pages.each { |page| pdf.pages << pdf.import(page) }
          template_pdf = HexaPDF::Document.open(template_tempfile.path)
          template_pdf.pages.each { |page| pdf.pages << pdf.import(page) }
          pdf.write(@tempfile.path, optimize: true)
          @tempfile.rewind
        end

        def cleanup_tempfiles(template_tempfile, next_steps_tempfile)
          template_tempfile.unlink
          next_steps_tempfile.unlink if next_steps_page?
        end
      end
    end
  end
end
