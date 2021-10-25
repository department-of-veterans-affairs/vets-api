# frozen_string_literal: true

require 'rails_helper'

describe DependentsVerificationsSerializer do
  subject { described_class.new(diaries).prompt_renewal }

  describe '#prompt_renewal' do
    context 'when there are multiple entries in the diaries call' do
      let(:diaries) do
        VCR.use_cassette('bgs/diaries_service/read_diaries') do
          BGS::DependencyVerificationService.new(create(:evss_user, :loa3)).read_diaries
        end
      end

      it "returns true when at least one has a diary_reason_type of '24'
      AND a diary_lc_status_type of 'PEND' AND the due_date is within a year" do
        expect(subject).to eq true
      end
    end

    context 'when there is one entry in the diaries call' do
      let(:diaries) do
        VCR.use_cassette('bgs/diaries_service/read_diaries_one_entry') do
          BGS::DependencyVerificationService.new(create(:evss_user, :loa3)).read_diaries
        end
      end

      it "returns true when it has a diary_reason_type of '24'
      AND a diary_lc_status_type of 'PEND' AND the due_date is within a year" do
        expect(subject).to eq true
      end

      context 'and the due_date is in the future' do
        let(:cassette_due_date) { Time.zone.parse('2014-05-01T00:00:00-05:00') }

        before { Timecop.freeze(cassette_due_date - time_jump) }

        after { Timecop.return }

        context 'by 6 years and 11 months' do
          let(:time_jump) { 6.years + 11.months }

          it 'returns true when the diary_entry is due less than 7 years from now' do
            expect(subject).to eq true
          end
        end

        context 'by 7 years and 1 day' do
          let(:time_jump) { 7.years + 1.day }

          it 'returns false when the diary_entry is due more than 7 years from now' do
            expect(subject).to eq false
          end
        end
      end
    end

    context 'when there are no entries in the diaries call' do
      let(:diaries) do
        VCR.use_cassette('bgs/diaries_service/read_diaries_no_entries') do
          BGS::DependencyVerificationService.new(create(:evss_user, :loa3)).read_diaries
        end
      end

      it 'returns false' do
        expect(subject).to eq false
      end
    end

    context "when the entry has a staus of 'CXCL'" do
      let(:diaries) do
        VCR.use_cassette('bgs/diaries_service/read_diaries_one_entry_cxcl') do
          BGS::DependencyVerificationService.new(create(:evss_user, :loa3)).read_diaries
        end
      end

      it 'returns false' do
        expect(subject).to eq false
      end
    end
  end
end
