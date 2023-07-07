# frozen_string_literal: true

require 'central_mail/datestamp_pdf'

module SimpleFormsApi
  class PdfStamper
    FORM_REQUIRES_STAMP = %w[26-4555 21-4142 21-10210 21P-0847].freeze
    SUBMISSION_TEXT = 'Signed electronically and submitted via VA.gov at '

    def self.stamp_pdf(stamped_template_path, data)
      if FORM_REQUIRES_STAMP.include? data['form_number']
        stamp_method = "stamp#{data['form_number'].gsub('-', '')}".downcase
        send(stamp_method, stamped_template_path, data)
      end
      current_time = Time.current.in_time_zone('America/Chicago').strftime('%H:%M:%S')
      stamp_text = SUBMISSION_TEXT + current_time
      desired_stamps = [[10, 10, stamp_text]]
      stamp(desired_stamps, stamped_template_path, text_only: false)
    end

    def self.stamp264555(stamped_template_path, data)
      desired_stamps = []
      desired_stamps.append([73, 390, 'X']) if data['previous_sah_application']['has_previous_sah_application'] == false
      desired_stamps.append([73, 355, 'X']) if data['previous_hi_application']['has_previous_hi_application'] == false
      desired_stamps.append([73, 320, 'X']) if data['living_situation']['is_in_care_facility'] == false
      stamp(desired_stamps, stamped_template_path)
    end

    def self.stamp214142(stamped_template_path, data)
      desired_stamps = [[50, 560]]
      first_name = data.dig('preparer_identification', 'preparer_full_name', 'first')
      middle_name = data.dig('preparer_identification', 'preparer_full_name', 'middle')
      last_name = data.dig('preparer_identification', 'preparer_full_name', 'last')
      suffix = data.dig('preparer_identification', 'preparer_full_name', 'suffix')
      signature_text = "#{first_name} #{middle_name} #{last_name} #{suffix}"
      page_configuration = [
        { type: :new_page },
        { type: :text, position: desired_stamps[0] },
        { type: :new_page }
      ]

      multistamp(stamped_template_path, signature_text, page_configuration)
    end

    def self.stamp2110210(stamped_template_path, data)
      desired_stamps = [[50, 160]]
      first_name, middle_name, last_name = get_name_to_stamp10210(data)
      signature_text = "#{first_name} #{middle_name} #{last_name}"
      page_configuration = [
        { type: :new_page },
        { type: :new_page },
        { type: :text, position: desired_stamps[0] }
      ]

      multistamp(stamped_template_path, signature_text, page_configuration)
    end

    def self.stamp21p0847(stamped_template_path, data)
      desired_stamps = [[50, 190]]
      first_name = data.dig('preparer_name', 'first')
      middle_name = data.dig('preparer_name', 'middle')
      last_name = data.dig('preparer_name', 'last')
      signature_text = "#{first_name} #{middle_name} #{last_name}"
      page_configuration = [
        { type: :new_page },
        { type: :text, position: desired_stamps[0] }
      ]

      multistamp(stamped_template_path, signature_text, page_configuration)
    end

    def self.multistamp(stamped_template_path, signature_text, page_configuration)
      stamp_path = Common::FileHelpers.random_file_path
      Prawn::Document.generate(stamp_path, margin: [0, 0]) do |pdf|
        page_configuration.each do |config|
          case config[:type]
          when :text
            pdf.draw_text signature_text, at: config[:position], size: 16
          when :new_page
            pdf.start_new_page
          end
        end
      end

      perform_multistamp(stamped_template_path, stamp_path)
    rescue => e
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

    def self.stamp(desired_stamps, stamped_template_path, text_only: true)
      current_file_path = stamped_template_path
      desired_stamps.each do |x, y, text|
        out_path = CentralMail::DatestampPdf.new(current_file_path).run(text:, x:, y:, text_only:)
        current_file_path = out_path
      end
      File.rename(current_file_path, stamped_template_path)
    end

    def self.perform_multistamp(stamped_template_path, stamp_path)
      out_path = "#{Common::FileHelpers.random_file_path}.pdf"
      pdftk = PdfFill::Filler::PDF_FORMS
      pdftk.multistamp(stamped_template_path, stamp_path, out_path)
      File.delete(stamped_template_path)
      File.rename(out_path, stamped_template_path)
    rescue
      Common::FileHelpers.delete_file_if_exists(out_path)
      raise
    end
  end
end
