# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeleteOldPiiLogsJob, type: :model do
  let!(:old_log) { create(:personal_information_log, created_at: 3.weeks.ago) }
  let!(:new_log) { create(:personal_information_log, created_at: 1.week.ago) }

  describe '#perform' do
    it 'deletes old records' do
      expect { subject.perform }.to change(PersonalInformationLog, :count).from(2).to(1)
      expect(model_exists?(new_log)).to be(true)
    end

    it 'deletes old records in batches' do
      expect { subject.perform }.to change { PersonalInformationLog.where('created_at < ?', 2.weeks.ago).count }.to(0)
      expect(model_exists?(new_log)).to be(true)
    end

    it 'does not delete new records' do
      subject.perform
      expect(PersonalInformationLog.exists?(new_log.id)).to be(true)
    end
  end
end
