# frozen_string_literal: true

require 'central_mail/datestamp_pdf'

module AppealsApi
  module PdfConstruction
    class Generator
      def initialize(appeal, version: 'V1')
        @appeal = appeal
        @structure = appeal.pdf_structure(version)
      end

      def generate
        @form_fill_path = fill_unique_form_fields
        #=> '{appeal.id}-tmp.pdf' OR '/tmp/#{appeal.id}-overlaid-form-fill-tmp.pdf'

        @unstamped_path = insert_additional_pages
        #=> '#{appeal.id}-completed-unstamped-tmp.pdf OR @form_fill_path'

        stamp
      end

      private

      attr_accessor :appeal, :structure

      def fill_unique_form_fields
        pdftk = PdfForms.new(Settings.binaries.pdftk)
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

      def stamp
        stamper = CentralMail::DatestampPdf.new(@unstamped_path)

        bottom_stamped_path = stamper.run(
          text: "API.VA.GOV #{Time.zone.now.utc.strftime('%Y-%m-%d %H:%M%Z')}",
          x: 5,
          y: 5,
          text_only: true
        )

        stamped_pdf_path = CentralMail::DatestampPdf.new(bottom_stamped_path).run(
          text: "Submitted by #{appeal.consumer_name} via api.va.gov",
          x: 429,
          y: 775,
          text_only: true
        )

        # This line is due to HLR being live when the updated stamp was added.
        # Once HLR bumps a version, we should refactor NoD's stamp method to be
        # generic to HLR/NOD/SC. For now, the HLR#Structure.stamp method will
        # just return the stamped path.
        structure.stamp(stamped_pdf_path)
      end

      def combine_form_fill_and_additional_pages(additional_pages_added_path)
        path = "/tmp/#{appeal.id}-completed-unstamped-tmp.pdf"
        unstamped_completed_pdf = CombinePDF.load(@form_fill_path) << CombinePDF.load(additional_pages_added_path)
        unstamped_completed_pdf.save(path)

        path
      end

      def pdf_template_path
        Rails.root.join('modules', 'appeals_api', 'config', 'pdfs')
      end
    end

    class InvalidPdfClass < StandardError; end
  end
end
