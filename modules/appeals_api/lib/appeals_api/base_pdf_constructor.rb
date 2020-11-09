# frozen_string_literal: true

require 'central_mail/datestamp_pdf'

module AppealsApi
  class BasePdfConstructor
    PDF_TEMPLATE = Rails.root.join('modules', 'appeals_api', 'config', 'pdfs')

    # The appeal that the PDF is being constructed for. i.e. HigherLevelReview, NoticeOfDisagreement, etc
    def appeal
      raise NotImplementedError, 'Subclass of BasePdfConstructor must implement appeal method'
    end

    # The title of the form being generated. i.e. 10182, 200996, etc
    def self.form_title
      raise NotImplementedError, 'Subclass of BasePdfConstructor must implement form_title method'
    end

    # The pdf_options used to generate the form, passed into pdftk.fill_form()
    def pdf_options
      raise NotImplementedError, 'Subclass of BasePdfConstructor must implement pdf_options method'
    end

    def fill_pdf
      pdftk = PdfForms.new(Settings.binaries.pdftk)
      temp_path = "#{Rails.root}/tmp/#{appeal.id}"
      output_path = temp_path + '-final.pdf'
      pdftk.fill_form(
        "#{PDF_TEMPLATE}/#{self.class.form_title}.pdf",
        temp_path,
        pdf_options,
        flatten: true
      )
      merge_page(temp_path, output_path)
    end

    def merge_page(temp_path, output_path)
      new_path = if pdf_options[:additional_page]
                   pdf = CombinePDF.new
                   pdf << CombinePDF.load(temp_path)
                   pdf << CombinePDF.load(add_page(pdf_options[:additional_page], temp_path))
                   pdf.save(output_path)
                   output_path
                 else
                   temp_path
                 end
      new_path
    end

    def add_page(text, temp_path)
      output_path = temp_path + '-additional_page.pdf'
      Prawn::Document.generate output_path do
        text text
      end
      output_path
    end

    def stamp_pdf(pdf_path, consumer_name)
      stamper = CentralMail::DatestampPdf.new(pdf_path)
      bottom_stamped_path = stamper.run(
        text: "API.VA.GOV #{Time.zone.now.utc.strftime('%Y-%m-%d %H:%M%Z')}",
        x: 5,
        y: 5,
        text_only: true
      )
      CentralMail::DatestampPdf.new(bottom_stamped_path).run(
        text: "Submitted by #{consumer_name} via api.va.gov",
        x: 429,
        y: 775,
        text_only: true
      )
    end
  end
end
