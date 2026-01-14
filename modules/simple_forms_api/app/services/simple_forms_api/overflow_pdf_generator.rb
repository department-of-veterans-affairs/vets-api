# frozen_string_literal: true

require 'prawn'
require 'securerandom'

module SimpleFormsApi
  class OverflowPdfGenerator
    HEADER = 'VA Form 21-4138 — Overflow data from remark section'
    CUTOFF_INDEX = 3685

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
      Rails.logger.error("Failed to generate overflow PDF: #{e.class} - #{e.message}\n#{e.backtrace&.join("\n")}")
      FileUtils.rm_f(file_path) if file_path && File.exist?(file_path)
      nil
    end

    private

    def overflow_text
      statement = (@data['statement'] || '').to_s
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
      s = ssn.gsub(/\D/, '')
      return ssn unless s.length == 9
      "#{s[0..2]}-#{s[3..4]}-#{s[5..8]}"
    end
  end
end