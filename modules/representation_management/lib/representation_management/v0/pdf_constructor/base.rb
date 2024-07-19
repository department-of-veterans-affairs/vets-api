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

        def construct(data, id: SecureRandom.uuid)
          set_template_path
          # fill_pdf(data)
          # combine_pdf(id, @template_path)
          fill_and_combine_pdf(data, id)
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

        private

        #
        # Produce final pdf with all pages combined.
        #
        # @param id [type] [description]
        # @param template_path [String] Path to page 1 of pdf
        # @param page2_path [String] Path to page 2 of pdf
        #
        # @return [String] Path to final pdf
        def combine_pdf(id, template_path)
          output_path = "/tmp/#{id}_final.pdf"

          pdf = CombinePDF.new
          pdf << CombinePDF.load(template_path)
          pdf.save(output_path)

          output_path
        end

        #
        # Fill in pdf form fields based on data provided.
        #
        # @param data [Hash] Data to fill in pdf form with
        def fill_pdf(data)
          pdftk = PdfForms.new(Settings.binaries.pdftk)

          Tempfile.create(["poa_#{Time.now.to_i}_page_1", '.pdf'], Rails.root.join('tmp')) do |tempfile|
            p "template_options(data): #{template_options(data)}", "tempfile path: #{tempfile.path}",
              "template_path: #{@template_path}"
            pdftk.fill_form(
              @template_path,
              tempfile.path,
              template_options(data),
              flatten: true
            )
            # Ensure the file is not deleted until we are done with it
            tempfile.close
            @template_path = tempfile.path
          end
          # Tempfile is automatically deleted here, but @template_path has been updated
          # If you need to use the tempfile beyond this block, consider adjustments.
        end

        def fill_and_combine_pdf(data, id)
          pdftk = PdfForms.new(Settings.binaries.pdftk)

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
          template_tempfile.unlink

          output_path
        end
      end
    end
  end
end
