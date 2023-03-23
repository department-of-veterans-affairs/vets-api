# frozen_string_literal: true

require 'central_mail/datestamp_pdf'

module FormsApi
  class PdfStamper
    FORM_REQUIRES_STAMP = ['26-4555'].freeze
    SUBMISSION_TEXT = 'Signed electronically and submitted via VA.gov at '

    def self.stamp_pdf(generated_form_path, data)
      if FORM_REQUIRES_STAMP.include? data['form_number']
        stamp_method = "stamp#{data['form_number'].gsub('-', '')}"
        send(stamp_method, generated_form_path, data)
      end
      centrail_mail_stamper = CentralMail::DatestampPdf.new(generated_form_path)
      current_time = Time.new.getlocal.strftime('%H:%M:%S')
      stamp_text = SUBMISSION_TEXT + current_time
      out_path = centrail_mail_stamper.run(text: stamp_text, x: 10, y: 10)
      File.rename(out_path, generated_form_path)
    end

    def self.stamp264555(generated_form_path, data)
      desired_stamps = []
      desired_stamps.append([73, 390]) if data['previous_sah_application']['has_previous_sah_application'] == false
      desired_stamps.append([73, 355]) if data['previous_hi_application']['has_previous_hi_application'] == false
      desired_stamps.append([73, 320]) if data['living_situation']['is_in_care_facility'] == false
      current_file_path = generated_form_path
      desired_stamps.each do |x, y|
        out_path = CentralMail::DatestampPdf.new(current_file_path).run(text: 'X', x:, y:, text_only: true)
        current_file_path = out_path
      end
      File.rename(current_file_path, generated_form_path)
    end
  end
end
