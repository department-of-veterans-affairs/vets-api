# frozen_string_literal: true

require 'rails_helper'

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement
      module V2
        describe FormData do
          let(:notice_of_disagreement) { create(:notice_of_disagreement_v2, :board_review_hearing) }
          let(:signing_appellant) { notice_of_disagreement.signing_appellant }
          let(:form_data) { described_class.new(notice_of_disagreement) }

          describe '#veteran_phone' do
            it { expect(form_data.veteran_phone).to eq '555-800-1111' }
          end

          describe '#veteran_email' do
            it { expect(form_data.veteran_email).to eq 'clause@north.com' }
          end

          describe '#veteran_homeless' do
            it { expect(form_data.veteran_homeless).to eq 'Off' }
          end

          describe '#direct_review' do
            it { expect(form_data.direct_review).to eq 'Off' }
          end

          describe '#evidence_submission' do
            it { expect(form_data.evidence_submission).to eq 1 }
          end

          describe '#hearing' do
            it { expect(form_data.hearing).to eq 'Off' }
          end

          describe '#additional_pages' do
            it { expect(form_data.additional_pages).to eq 'Off' }
          end

          describe '#signature' do
            it { expect(form_data.signature).to eq "Jäñe Doe\n- Signed by digital authentication to api.va.gov" }
          end

          describe '#date_signed formatted' do
            let(:month) { Time.now.in_time_zone(signing_appellant.timezone).strftime('%m') }
            let(:day) { Time.now.in_time_zone(signing_appellant.timezone).strftime('%d') }
            let(:year) { Time.now.in_time_zone(signing_appellant.timezone).strftime('%Y') }

            it { expect(form_data.date_signed_mm).to eq month }
            it { expect(form_data.date_signed_dd).to eq day }
            it { expect(form_data.date_signed_yyyy).to eq year }
          end

          describe '#stamp_text' do
            it { expect(form_data.stamp_text).to eq 'Doe - 987654321' }
          end

          context 'when delegating to notice of disagreement' do
            describe '#appellant_local_time' do
              it do
                expect(notice_of_disagreement).to receive(:appellant_local_time)
                form_data.appellant_local_time
              end
            end

            describe '#board_review_value' do
              it do
                expect(notice_of_disagreement).to receive(:board_review_value)
                form_data.board_review_value
              end
            end

            describe '#contestable_issues' do
              it do
                expect(notice_of_disagreement).to receive(:contestable_issues)
                form_data.contestable_issues
              end
            end

            describe '#extension_request?' do
              it do
                expect(notice_of_disagreement).to receive(:extension_request?)
                form_data.extension_request?
              end
            end

            describe '#representative_name' do
              it do
                expect(notice_of_disagreement).to receive(:representative_name)
                form_data.representative_name
              end
            end

            describe '#signing_appellant' do
              it do
                expect(notice_of_disagreement).to receive(:signing_appellant)
                form_data.signing_appellant
              end
            end

            describe '#veteran' do
              it do
                expect(notice_of_disagreement).to receive(:veteran)
                form_data.veteran
              end
            end

            describe '#veteran_homeless?' do
              it do
                expect(notice_of_disagreement).to receive(:veteran_homeless?)
                form_data.veteran_homeless?
              end
            end
          end
        end
      end
    end
  end
end
