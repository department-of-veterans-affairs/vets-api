# frozen_string_literal: true

require_relative '../v2/structure_spec'

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement
      module V3
        describe Structure do
          include_examples 'notice of disagreements v2 and v3 structure examples'

          describe 'form_title' do
            it 'returns the NOD doc title' do
              expect(described_class.new(notice_of_disagreement).form_title).to eq('10182_v3')
            end
          end
        end
      end
    end
  end
end
