# frozen_string_literal: true

require_relative '../v2/form_data_spec'

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement
      module V3
        describe FormData do
          include_examples 'notice of disagreements v2 and v3 form data examples'
        end
      end
    end
  end
end
