# frozen_string_literal: true

require 'central_mail/datestamp_pdf'

module FormsApi
  class PdfStamper
    FORM_REQUIRES_STAMP = %w[26-4555 21-4142 21-10210].freeze
    SUBMISSION_TEXT = 'Signed electronically and submitted via VA.gov at '

    def self.stamp_pdf(generated_form_path, data)
      if FORM_REQUIRES_STAMP.include? data['form_number']
        stamp_method = "stamp#{data['form_number'].gsub('-', '')}"
        send(stamp_method, generated_form_path, data)
      end
      current_time = Time.new.getlocal.strftime('%H:%M:%S')
      stamp_text = SUBMISSION_TEXT + current_time
      desired_stamps = [[10, 10, stamp_text]]
      stamp(desired_stamps, generated_form_path, text_only: false)
    end

    def self.stamp264555(generated_form_path, data)
      desired_stamps = []
      desired_stamps.append([73, 390, 'X']) if data['previous_sah_application']['has_previous_sah_application'] == false
      desired_stamps.append([73, 355, 'X']) if data['previous_hi_application']['has_previous_hi_application'] == false
      desired_stamps.append([73, 320, 'X']) if data['living_situation']['is_in_care_facility'] == false
      stamp(desired_stamps, generated_form_path)
    end

    def self.stamp214142(generated_form_path, data)
      desired_stamps = [[50, 560]]
      first_name = data.dig('preparer_identification', 'preparer_full_name', 'first')
      middle_name = data.dig('preparer_identification', 'preparer_full_name', 'middle')
      last_name = data.dig('preparer_identification', 'preparer_full_name', 'last')
      suffix = data.dig('preparer_identification', 'preparer_full_name', 'suffix')
      signature_text = "#{first_name} #{middle_name} #{last_name} #{suffix}"

      stamp_path = Common::FileHelpers.random_file_path
      Prawn::Document.generate(stamp_path, margin: [0, 0]) do |pdf|
        pdf.start_new_page
        pdf.draw_text signature_text, at: desired_stamps[0], size: 16
        pdf.start_new_page
      end

      multistamp(generated_form_path, stamp_path)
    rescue
      Rails.logger.error "Failed to generate stamped file: #{e.message}"
      raise
    ensure
      Common::FileHelpers.delete_file_if_exists(stamp_path) if defined?(stamp_path)
    end

    def self.stamp2110210(generated_form_path, data)
      first_name, middle_name, last_name = get_name_to_stamp10210(data)
      desired_stamps = [[50, 160]]
      signature_text = "#{first_name} #{middle_name} #{last_name}"

      stamp_path = Common::FileHelpers.random_file_path
      Prawn::Document.generate(stamp_path, margin: [0, 0]) do |pdf|
        pdf.start_new_page
        pdf.start_new_page
        pdf.draw_text signature_text, at: desired_stamps[0], size: 16
      end

      multistamp(generated_form_path, stamp_path)
    rescue
      Rails.logger.error "Failed to generate stamped file: #{e.message}"
      raise
    ensure
      Common::FileHelpers.delete_file_if_exists(stamp_path) if defined?(stamp_path)
    end

    def self.get_name_to_stamp10210(data)
      # claimant type values: 'veteran', 'non-veteran'
      # claimant ownership values: 'self', 'third-party'
      # third-party = witness
      # self, veteran = veteran
      # self, non-veteran = claimant
      first_name = data.dig('veteran_full_name', 'first')
      middle_name = data.dig('veteran_full_name', 'middle')
      last_name = data.dig('veteran_full_name', 'last')
      if data['claim_ownership'] == 'third-party'
        first_name = data.dig('witness_full_name', 'first')
        middle_name = data.dig('witness_full_name', 'middle')
        last_name = data.dig('witness_full_name', 'last')
      elsif data['claimant_type'] == 'non-veteran'
        first_name = data.dig('claimant_full_name', 'first')
        middle_name = data.dig('claimant_full_name', 'middle')
        last_name = data.dig('claimant_full_name', 'last')
      end
      [first_name, middle_name, last_name]
    end

    def self.stamp(desired_stamps, generated_form_path, text_only: true)
      current_file_path = generated_form_path
      desired_stamps.each do |x, y, text|
        out_path = CentralMail::DatestampPdf.new(current_file_path).run(text:, x:, y:, text_only:)
        current_file_path = out_path
      end
      File.rename(current_file_path, generated_form_path)
    end

    def self.multistamp(generated_form_path, stamp_path)
      out_path = "#{Common::FileHelpers.random_file_path}.pdf"
      pdftk = PdfFill::Filler::PDF_FORMS
      pdftk.multistamp(generated_form_path, stamp_path, out_path)
      File.delete(generated_form_path)
      File.rename(out_path, generated_form_path)
    rescue
      Common::FileHelpers.delete_file_if_exists(out_path)
      raise
    end
  end
end
