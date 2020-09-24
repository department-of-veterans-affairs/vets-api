# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeleteOldPiiLogsJob, type: :model do
  let!(:old_log) { create(:personal_information_log, created_at: 3.weeks.ago) }
  let!(:new_log) { create(:personal_information_log, created_at: 1.week.ago) }

  describe '#perform' do
    it 'deletes old records' do
      expect { subject.perform }.to change(PersonalInformationLog, :count).from(2).to(1)
      expect(model_exists?(new_log)).to eq(true)
    end
  end
end
