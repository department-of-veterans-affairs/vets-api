# frozen_string_literal: true

require 'rails_helper'

describe DependentsVerificationsSerializer do
  subject { described_class.new(diaries) }

  let(:diaries) do
    VCR.use_cassette('bgs/diaries_service/read_diaries') do
      BGS::DependencyVerificationService.new(create(:evss_user, :loa3)).read_diaries
    end
  end

  describe '#prompt_renewal' do
    it "returns true when there is a diary entry with a diary_reason_type of '24'
      AND a diary_lc_status_type of 'PEND' AND the due_date is within a year" do
      expect(subject.prompt_renewal).to eq true
    end
  end
end
