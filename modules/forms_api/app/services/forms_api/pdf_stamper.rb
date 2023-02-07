# frozen_string_literal: true

require 'central_mail/datestamp_pdf'

module FormsApi
  class PdfStamper
    def self.stamp_pdf(generated_form_path, data)
      stamp_method = "stamp_#{data['form_number'].gsub('_', '')}"
      send(stamp_method, generated_form_path, data)
    end

    def self.stamp_vba264555(generated_form_path, data)
      desired_stamps = []
      desired_stamps.append([73, 390]) if data['previousSahApplication']['hasPreviousSahApplication'] == false
      desired_stamps.append([73, 355]) if data['previousHiApplication']['hasPreviousHiApplication'] == false
      desired_stamps.append([73, 320]) if data['livingSituation']['isInCareFacility'] == false
      current_file_path = generated_form_path
      desired_stamps.each do |x, y|
        out_path = CentralMail::DatestampPdf.new(current_file_path).run(text: 'X', x: x, y: y, text_only: true)
        current_file_path = out_path
      end
      File.rename(current_file_path, generated_form_path)
    end
  end
end
