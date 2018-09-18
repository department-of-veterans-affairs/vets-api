# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InProgressFormCleaner do
  before do
    now = Time.now.utc
    Timecop.freeze(now - 61.days)
    @form_expired = create(:in_progress_form)
    Timecop.freeze(now - 59.days)
    @form_active = create(:in_progress_form)
    Timecop.freeze(now)
    @form_new = create(:in_progress_form)
  end

  after { Timecop.return }

  describe '#perform' do
    it 'deletes old records' do
      expect { subject.perform }.to change { InProgressForm.count }.by(-1)
      expect { @form_expired.reload }.to raise_exception(ActiveRecord::RecordNotFound)
    end
  end
end
