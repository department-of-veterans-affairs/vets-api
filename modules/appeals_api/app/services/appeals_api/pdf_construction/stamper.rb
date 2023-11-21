# frozen_string_literal: true

require 'central_mail/datestamp_pdf'

module AppealsApi
  module PdfConstruction
    class Stamper
      def initialize(appeal, pdf_path)
        @pdf_path = pdf_path
        @appeal = appeal
      end

      def call
        CentralMail::DatestampPdf.new(nil).stamp(date_and_consumer_stamp_path, veteran_stamp_path)
      end

      private

      def date_stamp_path
        CentralMail::DatestampPdf.new(@pdf_path).run(
          text: "API.VA.GOV #{@appeal.created_at.utc.strftime('%Y-%m-%d %H:%M%Z')}",
          x: 5,
          y: 782,
          text_only: true,
          size: 8
        )
      end

      def date_and_consumer_stamp_path
        text = generate_text(10, @appeal.consumer_name || '')
        CentralMail::DatestampPdf.new(date_stamp_path).run(
          text:,
          x: 445,
          y: 782,
          text_only: true,
          size: 8
        )
      end

      def veteran_stamp_path
        veteran_stamp_path = "#{Common::FileHelpers.random_file_path}.pdf"
        Prawn::Document.generate(veteran_stamp_path, margin: [0, 0]) do |pdf|
          pdf.text_box @appeal.stamp_text,
                       at: [140, 789],
                       align: :center,
                       valign: :center,
                       overflow: :shrink_to_fit,
                       min_font_size: 8,
                       width: 295,
                       height: 8
        end
        veteran_stamp_path
      end

      def generate_text(name_max_length, consumer_name)
        leading_space = '  ' * (name_max_length - consumer_name.length).abs
        if consumer_name.length > name_max_length
          "Submitted by #{consumer_name.truncate(name_max_length)} via api.va.gov"
        else
          "#{leading_space}Submitted by #{consumer_name} via api.va.gov"
        end
      end
    end
  end
end
