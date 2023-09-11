# frozen_string_literal: true

require 'central_mail/datestamp_pdf'

module AppealsApi
  module PdfConstruction
    class Generator
      def initialize(appeal, pdf_version: 'v1')
        @appeal = appeal
        appeal.update(pdf_version:) if appeal.pdf_version.blank?
        appeal.pdf_output_prep if appeal.respond_to? :pdf_output_prep
        @structure = appeal.pdf_structure(pdf_version)
      end

      def generate
        @form_fill_path = fill_unique_form_fields
        #=> '{appeal.id}-tmp.pdf' OR '/tmp/#{appeal.id}-overlaid-form-fill-tmp.pdf'

        @all_pages_path = insert_additional_pages
        #=> '#{appeal.id}-completed-unstamped-tmp.pdf OR @form_fill_path'

        unstamped_path = finalize_pages
        #=> '#{appeal.id}-rebuilt-pages-tmp.pdf OR @all_pages_path'

        AppealsApi::PdfConstruction::Stamper.new(appeal, unstamped_path).call
      end

      private

      attr_accessor :appeal, :structure

      def fill_unique_form_fields
        form_fill_path = "/tmp/#{appeal.id}-tmp"

        pdftk.fill_form(
          "#{pdf_template_path}/#{structure.form_title}.pdf",
          form_fill_path,
          structure.form_fill,
          flatten: true
        )

        structure.insert_overlaid_pages(form_fill_path)
      end

      def insert_additional_pages
        # add_additional_pages should always return a Prawn::Document object
        pdf = structure.add_additional_pages

        return @form_fill_path if pdf.blank?

        raise InvalidPdfClass if pdf.class != Prawn::Document

        additional_pages_added_path = "/tmp/#{appeal.id}-additional-pages-tmp.pdf"
        pdf.render_file(additional_pages_added_path) # saves the file

        combine_form_fill_and_additional_pages(additional_pages_added_path)
      end

      def finalize_pages
        return @all_pages_path unless structure.final_page_adjustments

        adjusted_pages_path = "/tmp/#{appeal.id}-rebuilt-pages-tmp.pdf"
        pdftk.cat({ @all_pages_path => structure.final_page_adjustments }, adjusted_pages_path)
        adjusted_pages_path
      end

      def combine_form_fill_and_additional_pages(additional_pages_added_path)
        path = "/tmp/#{appeal.id}-completed-unstamped-tmp.pdf"

        pdftk.cat(@form_fill_path, additional_pages_added_path, path)

        path
      end

      def pdftk
        @pdftk ||= PdfForms.new(Settings.binaries.pdftk)
      end

      def pdf_template_path
        Rails.root.join('modules', 'appeals_api', 'config', 'pdfs')
      end
    end

    class InvalidPdfClass < StandardError; end
  end
end
