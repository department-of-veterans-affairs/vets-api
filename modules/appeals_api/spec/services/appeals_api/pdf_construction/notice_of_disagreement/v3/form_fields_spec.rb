# frozen_string_literal: true

require_relative '../v2/form_fields_spec'

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement
      module V3
        describe FormFields do
          include_examples 'notice of disagreements v2 and v3 form fields examples'
        end
      end
    end
  end
end
