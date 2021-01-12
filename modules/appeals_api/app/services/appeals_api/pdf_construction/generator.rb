require 'central_mail/datestamp_pdf'

module AppealsApi
  module PdfConstruction
    class Generator
      def initialize(appeal)
        @appeal = appeal.decorated_for_pdf
      end

      def generate
        fill_unique_form_fields

        # insert_additional_pages

        #this doesn't yet have a valid path to use
        stamp
      end

      private

      attr_accessor :appeal

      def fill_unique_form_fields
        pdftk = PdfForms.new(Settings.binaries.pdftk)
        temp_path = "/tmp/#{appeal.id}"

        pdftk.fill_form(
          "#{pdf_template_path}/#{appeal.form_title}.pdf",
          temp_path,
          appeal.form_fill,
          flatten: true
        )
      end

      def stamp
        stamper = CentralMail::DatestampPdf.new(pdf_path)
        bottom_stamped_path = stamper.run(
          text: "API.VA.GOV #{Time.zone.now.utc.strftime('%Y-%m-%d %H:%M%Z')}",
          x: 5,
          y: 5,
          text_only: true
        )
        CentralMail::DatestampPdf.new(bottom_stamped_path).run(
          text: "Submitted by #{appeal.consumer_name} via api.va.gov",
          x: 429,
          y: 775,
          text_only: true
        )
      end

      def pdf_path
        "/tmp/#{appeal.id}-final.pdf"
      end

      def pdf_template_path
        Rails.root.join('modules', 'appeals_api', 'config', 'pdfs')
      end
    end
  end
end
