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

        def construct(data)
          set_template_path
          fill_and_combine_pdf(data)
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

        private

        #
        # Fill in pdf form fields based on data provided, then combine all
        # the pages into a final pdf.  We create an inner tempfile to fill
        # and the output from this method is written to a tempfile in
        # the controller.
        #
        # @param data [Hash] Data to fill in pdf form with
        def fill_and_combine_pdf(data)
          pdftk = PdfForms.new(Settings.binaries.pdftk)

          # We need a Tempfile here because CombinePDF needs a file to load.
          template_tempfile = Tempfile.new
          pdftk.fill_form(
            @template_path,
            template_tempfile.path,
            template_options(data),
            flatten: true
          )
          @template_path = template_tempfile.path
          template_tempfile.rewind

          output_path = @tempfile.path

          pdf = CombinePDF.new
          pdf << CombinePDF.load(@template_path)
          pdf.save(output_path)

          @tempfile.rewind
          # Delete the tempfile we created now that CombinePDF has saved
          # the final pdf.
          template_tempfile.unlink
        end
      end
    end
  end
end
