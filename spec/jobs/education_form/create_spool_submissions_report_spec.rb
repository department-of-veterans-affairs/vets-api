# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::CreateSpoolSubmissionsReport do
  let(:date) { Time.zone.today - 1.day }
  subject do
    described_class.new
  end

  describe '#create_csv_array' do
    before do
      subject.instance_variable_set(:@date, date)
      create(:education_benefits_claim_1990e, processed_at: date)
      create(:education_benefits_claim_1990n, processed_at: date)
    end

    it 'should create the right array' do
      expect(
        subject.create_csv_array
      ).to eq(
        [["Claimant Name", "Veteran Name", "Date Submitted", "RPO"],
   ["Mark Olson", nil, "2017-07-26 00:00:00 UTC", "eastern"],
   [nil, "Mark Olson", "2017-07-26 00:00:00 UTC", "eastern"]]
      )
    end
  end
end
