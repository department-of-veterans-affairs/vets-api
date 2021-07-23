# frozen_string_literal: true

require 'rails_helper'

describe DependentsVerificationsSerializer do
  subject { described_class.new(diaries) }

  describe '#prompt_renewal' do
    context 'when there are multiple entries in the diaries call' do
      let(:diaries) do
        VCR.use_cassette('bgs/diaries_service/read_diaries') do
          BGS::DependencyVerificationService.new(create(:evss_user, :loa3)).read_diaries
        end
      end

      it "returns true when at least one has a diary_reason_type of '24'
      AND a diary_lc_status_type of 'PEND' AND the due_date is within a year" do
        expect(subject.prompt_renewal).to eq true
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
        expect(subject.prompt_renewal).to eq true
      end
    end

    context 'when there are no entries in the diaries call' do
      let(:diaries) do
        VCR.use_cassette('bgs/diaries_service/read_diaries_no_entries') do
          BGS::DependencyVerificationService.new(create(:evss_user, :loa3)).read_diaries
        end
      end

      it 'returns false' do
        expect(subject.prompt_renewal).to eq false
      end
    end

    context "when the entry has a staus of 'CXCL'" do
      let(:diaries) do
        VCR.use_cassette('bgs/diaries_service/read_diaries_one_entry_cxcl') do
          BGS::DependencyVerificationService.new(create(:evss_user, :loa3)).read_diaries
        end
      end

      it 'returns false' do
        expect(subject.prompt_renewal).to eq false
      end
    end
  end
end
