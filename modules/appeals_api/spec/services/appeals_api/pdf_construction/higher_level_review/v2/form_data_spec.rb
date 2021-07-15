# frozen_string_literal: true

require 'rails_helper'

module AppealsApi
  module PdfConstruction
    module HigherLevelReview
      module V2
        describe FormData do
          describe '#stamp_text' do
            let(:higher_level_review) { build(:higher_level_review) }
            let(:form_data) { described_class.new(higher_level_review) }

            it { expect(form_data.stamp_text).to eq('Doe - 6789') }

            it 'truncates the last name if too long' do
              full_last_name = 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdddddddddd'
              higher_level_review.auth_headers['X-VA-Last-Name'] = full_last_name
              expect(form_data.stamp_text).to eq 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdd... - 6789'
            end
          end

          describe '#rep_country_code' do
            it 'defaults to 1 if countryCode is blank' do
              higher_level_review = build_stubbed(:higher_level_review)
              form_data = described_class.new(higher_level_review)
              allow(higher_level_review).to receive(:informal_conference_rep_phone).and_return(
                AppealsApi::HigherLevelReview::Phone.new(
                  { 'areaCode' => '555', 'phoneNumber' => '8001111', 'phoneNumberExt' => '2' }
                )
              )

              expect(form_data.rep_country_code).to eq('1')
            end
          end
        end
      end
    end
  end
end
