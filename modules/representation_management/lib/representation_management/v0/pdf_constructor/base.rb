# frozen_string_literal: true

require 'pdf_fill/filler'

module RepresentationManagement
  module V0
    module PdfConstructor
      class Base
        def initialize
          @template_path = nil
          @page2_path = nil
          @page3_path = nil
          @page4_path = nil
        end

        def construct(data, id: SecureRandom.uuid)
          fill_pdf(data)
          combine_pdf(id, @template_path, @page2_path, @page3_path, @page4_path)
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

        # @param data [Hash] Data to fill in pdf form
        #
        # @return [Hash] Data to fill in second page of pdf form
        def page2_options(_data)
          raise 'NotImplemented' # Extend this class and implement
        end

        #
        # Converts segmented address information into single string representation.
        #
        # @param address [Hash] Segmented data representing an address
        #
        # @return [String] Single string representation of provided address
        def stringify_address(address)
          return if address.nil?

          "#{address['addressLine1']}, #{address['city']} #{address['stateCode']} #{address['zipCode']}"
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
        def combine_pdf(id, template_path, page2_path, page3_path, page4_path)
          output_path = "/tmp/#{id}_final.pdf"

          pdf = CombinePDF.new
          pdf << CombinePDF.load(template_path)
          pdf << CombinePDF.load(page2_path)
          pdf << CombinePDF.load(page3_path) unless page3_path.nil?
          pdf << CombinePDF.load(page4_path) unless page4_path.nil?
          pdf.save(output_path)

          output_path
        end

        #
        # Fill in pdf form fields based on data provided.
        #
        # @param data [Hash] Data to fill in pdf form with
        def fill_pdf(data)
          pdftk = PdfForms.new(Settings.binaries.pdftk)

          temp_path = Rails.root.join('tmp', "poa_#{Time.now.to_i}_page_1.pdf")
          pdftk.fill_form(
            @template_path,
            temp_path,
            template_options(data),
            flatten: true
          )
          @template_path = temp_path

          temp_path = Rails.root.join('tmp', "poa_#{Time.now.to_i}_page_2.pdf")
          pdftk.fill_form(
            @page2_path,
            temp_path,
            page2_options(data),
            flatten: true
          )
          @page2_path = temp_path
        end

        def stamp(file_path, stamp_path, delete_source: true)
          output_path = "#{::Common::FileHelpers.random_file_path}.pdf"

          PdfFill::Filler::PDF_FORMS.stamp(file_path, stamp_path, output_path)
          File.delete(file_path) if delete_source

          output_path
        rescue
          ::Common::FileHelpers.delete_file_if_exists(output_path)
          raise
        end
      end
    end
  end
end
