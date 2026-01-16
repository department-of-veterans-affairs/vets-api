# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::DeleteOldEducationBenefitsClaims do
  let!(:claim1) { create(:va0803, delete_date: DateTime.new(2025, 2, 1, 0, 0, 0)) } # should be deleted
  let!(:claim2) { create(:va0803, delete_date: DateTime.new(2025, 2, 2, 0, 0, 0)) } # should be deleted
  # delete date in future, should be preserved
  let!(:claim3) do
    create(:va0803, delete_date: DateTime.new(2025, 5, 1, 0, 0, 0))
  end
  let!(:claim4) { create(:va0803, delete_date: nil) } # no delete date, should be preserved

  describe '#perform' do
    it 'deletes only the expected records' do
      Timecop.freeze(DateTime.new(2025, 2, 4)) do
        expect { subject.perform }
          .to change(SavedClaim, :count).from(4).to(2)
          .and change(EducationBenefitsClaim, :count).from(4).to(2)
      end
      expect(SavedClaim.pluck(:id)).to contain_exactly(claim3.id, claim4.id)
    end
  end
end
