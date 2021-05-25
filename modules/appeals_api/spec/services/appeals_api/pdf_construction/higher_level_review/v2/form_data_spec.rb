# frozen_string_literal: true

require 'rails_helper'

module AppealsApi
  module PdfConstruction
    module HigherLevelReview
      module V2
        describe FormData do
          let(:higher_level_review) { build(:higher_level_review) }
          let(:form_data) { described_class.new(higher_level_review) }

          describe '#stamp_text' do
            it { expect(form_data.stamp_text).to eq('Doe - 6789') }

            it 'truncates the last name if too long' do
              full_last_name = 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdddddddddd'
              higher_level_review.auth_headers['X-VA-Last-Name'] = full_last_name
              expect(form_data.stamp_text).to eq 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdd... - 6789'
            end
          end
        end
      end
    end
  end
end
