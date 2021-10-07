# frozen_string_literal: true

require 'rails_helper'

module AppealsApi
  module PdfConstruction
    module SupplementalClaim
      module V2
        describe FormData do
          describe '#stamp_text' do
            let(:supplemental_claim) { build(:supplemental_claim) }
            let(:form_data) { described_class.new(supplemental_claim) }

            it { expect(form_data.stamp_text).to eq('Doé - 6789') }

            it 'truncates the last name if too long' do
              full_last_name = 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdddddddddd'
              supplemental_claim.auth_headers['X-VA-Last-Name'] = full_last_name
              expect(form_data.stamp_text).to eq 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdd... - 6789'
            end
          end
        end
      end
    end
  end
end
