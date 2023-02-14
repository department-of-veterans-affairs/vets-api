# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement::V3
      class Structure < AppealsApi::PdfConstruction::NoticeOfDisagreement::V2::Structure
        def form_title
          '10182_v3'
        end
      end
    end
  end
end
