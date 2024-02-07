# frozen_string_literal: true

require 'central_mail/datestamp_pdf'

module SimpleFormsApi
  class PdfStamper
    FORM_REQUIRES_STAMP = %w[26-4555 21-4142 21-10210 21-0845 21P-0847 21-0966 21-0972].freeze
    SUBMISSION_TEXT = 'Signed electronically and submitted via VA.gov at '
    SUBMISSION_DATE_TITLE = 'Application Submitted:'

    def self.stamp_pdf(stamped_template_path, form, current_loa)
      form_number = form.data['form_number']
      if FORM_REQUIRES_STAMP.include? form_number
        stamp_method = "stamp#{form_number.gsub('-', '')}".downcase
        send(stamp_method, stamped_template_path, form)
      end

      current_time = Time.current.in_time_zone('America/Chicago').strftime('%H:%M:%S') + ' '
      auth_text = case current_loa
                  when 3
                    'Signee signed with an identity-verified account.'
                  when 1
                    'Signee signed in but hasn’t verified their identity.'
                  else
                    'Signee not signed in.'
                  end
      stamp_text = SUBMISSION_TEXT + current_time
      desired_stamps = [[10, 10, stamp_text]]
      stamp(desired_stamps, stamped_template_path, auth_text, text_only: false)

      stamp_submission_date(stamped_template_path, form.submission_date_config)
    end

    def self.stamp264555(stamped_template_path, form)
      desired_stamps = []
      desired_stamps.append([73, 390, 'X']) unless form.data['previous_sah_application']['has_previous_sah_application']
      desired_stamps.append([73, 355, 'X']) unless form.data['previous_hi_application']['has_previous_hi_application']
      desired_stamps.append([73, 320, 'X']) unless form.data['living_situation']['is_in_care_facility']
      append_to_stamp = false
      stamp(desired_stamps, stamped_template_path, append_to_stamp)
    end

    def self.stamp214142(stamped_template_path, form)
      desired_stamps = [[50, 560]]
      signature_text = form.data['statement_of_truth_signature']
      page_configuration = [
        { type: :new_page },
        { type: :text, position: desired_stamps[0] },
        { type: :new_page }
      ]

      multistamp(stamped_template_path, signature_text, page_configuration)

      # This is a one-off case where we need to stamp a date on the first page of 21-4142 when resubmitting
      if form.data['in_progress_form_created_at']
        date_title = 'Application Submitted:'
        date_text = form.data['in_progress_form_created_at']
        stamp214142_date_stamp_for_resubmission(stamped_template_path, date_title, date_text)
      end
    end

    def self.stamp214142_date_stamp_for_resubmission(stamped_template_path, date_title, date_text)
      date_title_stamp_position = [440, 710]
      date_text_stamp_position = [440, 690]
      page_configuration = [
        { type: :text, position: date_title_stamp_position },
        { type: :new_page },
        { type: :new_page }
      ]

      multistamp(stamped_template_path, date_title, page_configuration, 12)

      page_configuration = [
        { type: :text, position: date_text_stamp_position },
        { type: :new_page },
        { type: :new_page }
      ]

      multistamp(stamped_template_path, date_text, page_configuration, 12)
    end

    def self.stamp2110210(stamped_template_path, form)
      desired_stamps = [[50, 160]]
      signature_text = form.data['statement_of_truth_signature']
      page_configuration = [
        { type: :new_page },
        { type: :new_page },
        { type: :text, position: desired_stamps[0] }
      ]

      multistamp(stamped_template_path, signature_text, page_configuration)
    end

    def self.stamp210845(stamped_template_path, form)
      desired_stamps = [[50, 240]]
      signature_text = form.data['statement_of_truth_signature']
      page_configuration = [
        { type: :new_page },
        { type: :new_page },
        { type: :text, position: desired_stamps[0] }
      ]

      multistamp(stamped_template_path, signature_text, page_configuration)
    end

    def self.stamp21p0847(stamped_template_path, form)
      desired_stamps = [[50, 190]]
      signature_text = form.data['statement_of_truth_signature']
      page_configuration = [
        { type: :new_page },
        { type: :text, position: desired_stamps[0] }
      ]

      multistamp(stamped_template_path, signature_text, page_configuration)
    end

    def self.stamp210972(stamped_template_path, form)
      desired_stamps = [[50, 465]]
      signature_text = form.data['statement_of_truth_signature']
      page_configuration = [
        { type: :new_page },
        { type: :new_page },
        { type: :text, position: desired_stamps[0] }
      ]

      multistamp(stamped_template_path, signature_text, page_configuration)
    end

    def self.stamp210966(stamped_template_path, form)
      desired_stamps = [[50, 415]]
      signature_text = form.data['statement_of_truth_signature']
      page_configuration = [
        { type: :new_page },
        { type: :text, position: desired_stamps[0] }
      ]

      multistamp(stamped_template_path, signature_text, page_configuration)
    end

    def self.multistamp(stamped_template_path, signature_text, page_configuration, font_size = 16)
      stamp_path = Common::FileHelpers.random_file_path
      Prawn::Document.generate(stamp_path, margin: [0, 0]) do |pdf|
        page_configuration.each do |config|
          case config[:type]
          when :text
            pdf.draw_text signature_text, at: config[:position], size: font_size
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

    def self.stamp(desired_stamps, stamped_template_path, append_to_stamp, text_only: true)
      current_file_path = stamped_template_path
      desired_stamps.each do |x, y, text|
        out_path = CentralMail::DatestampPdf.new(current_file_path, append_to_stamp:).run(text:, x:, y:, text_only:)
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

    def self.stamp_submission_date(stamped_template_path, config)
      if config[:should_stamp_date?]
        date_title_stamp_position = config[:title_coords]
        date_text_stamp_position = config[:text_coords]
        page_configuration = [
          { type: :new_page },
          { type: :new_page },
          { type: :new_page },
          { type: :new_page }
        ]
        page_configuration[config[:page_number]] = { type: :text, position: date_title_stamp_position }

        multistamp(stamped_template_path, SUBMISSION_DATE_TITLE, page_configuration, 12)

        page_configuration = [
          { type: :new_page },
          { type: :new_page },
          { type: :new_page },
          { type: :new_page }
        ]
        page_configuration[config[:page_number]] = { type: :text, position: date_text_stamp_position }

        multistamp(stamped_template_path, Time.current.in_time_zone('UTC').strftime('%H:%M %Z %D'), page_configuration,
                   12)
      end
    end
  end
end
