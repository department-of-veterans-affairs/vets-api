# frozen_string_literal: true

require 'prawn'
require 'securerandom'

module SimpleFormsApi
  class OverflowPdfGenerator
    HEADER = 'VA Form 21-4138 — Overflow data from remark section'
    CUTOFF_INDEX = 3685 # last index filled by native remarks fields (0..1510, 1511..3685)

    def initialize(data, timestamp = Time.current, mask_ssn: true)
      @data = data || {}
      @timestamp = timestamp
      @mask_ssn = mask_ssn
    end

    def generate
      text = overflow_text
      return nil if text.blank?

      file_path = build_file_path
      generate_pdf(file_path, text)
      file_path
    rescue StandardError => e
      Rails.logger.error("Failed to generate overflow PDF: #{e.class} - #{e.message}")
      FileUtils.rm_f(file_path) if file_path && File.exist?(file_path)
      nil
    end

    private

    def overflow_text
      statement = (@data['statement'] || '').to_s
      # Overflow starts at index 3686; require length > 3686
      return '' unless statement.length > CUTOFF_INDEX + 1
      statement[(CUTOFF_INDEX + 1)..-1]
    end

    def build_file_path
      folder = Rails.root.join('tmp', 'pdfs')
      FileUtils.mkdir_p(folder)
      folder.join("21-4138_overflow_#{SecureRandom.uuid}.pdf").to_s
    end

    def generate_pdf(file_path, text)
      Prawn::Document.generate(file_path, page_size: 'LETTER', margin: 50) do |pdf|
        # If you want consistency with extras pages, swap to Roboto like:
        # pdf.font_families.update(
        #   'Roboto' => {
        #     normal: Rails.root.join('lib', 'pdf_fill', 'fonts', 'Roboto-Regular.ttf'),
        #     bold: Rails.root.join('lib', 'pdf_fill', 'fonts', 'Roboto-Bold.ttf')
        #   }
        # )
        # pdf.font('Roboto')
        pdf.font 'Helvetica'

        # Header
        pdf.text HEADER, size: 14, style: :bold, align: :center
        pdf.move_down 15

        # Identity block
        pdf.text veteran_name_line, size: 10
        pdf.text id_line, size: 10
        pdf.move_down 20

        # Overflow content
        pdf.text 'REMARKS (CONTINUED):', size: 11, style: :bold
        pdf.move_down 10
        pdf.text text, size: 10, leading: 2

        # Footer with timestamp (acceptance criteria: timestamp at bottom)
        add_footer(pdf)
      end
    end

    def veteran_name_line
      first = @data.dig('full_name', 'first').to_s
      middle = @data.dig('full_name', 'middle').to_s
      last = @data.dig('full_name', 'last').to_s
      full_name = [first, middle, last].reject(&:blank?).join(' ')
      "Name: #{full_name.presence || 'Not provided'}"
    end

    def id_line
      # Prefer VA file number if present; otherwise SSN
      va_file = @data.dig('id_number', 'va_file_number').to_s.presence
      ssn = @data.dig('id_number', 'ssn').to_s

      if va_file.present?
        "VA File Number: #{va_file}"
      elsif ssn.present?
        @mask_ssn ? "SSN: XXX-XX-#{ssn[5..8]}" : "SSN: #{format_ssn(ssn)}"
      else
        'ID: Not provided'
      end
    end

    def format_ssn(ssn)
      # Format 9-digit string to xxx-xx-xxxx if possible
      s = ssn.gsub(/\D/, '')
      return ssn unless s.length == 9
      "#{s[0..2]}-#{s[3..4]}-#{s[5..8]}"
    end

    def add_footer(pdf)
      pdf.number_pages(
        "Generated: #{formatted_timestamp}",
        at: [pdf.bounds.left, 0],
        align: :left,
        size: 9
      )
    end

    def formatted_timestamp
      @timestamp.in_time_zone('UTC').strftime('%Y-%m-%d %H:%M:%S %Z')
    end
  end
end