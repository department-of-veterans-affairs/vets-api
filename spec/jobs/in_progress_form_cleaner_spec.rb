# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InProgressFormCleaner do
  before do
    @form_nil = create(:in_progress_form, updated_at: nil)
    @form_new = create(:in_progress_form, updated_at: Time.now.utc)
    @form_old = create(:in_progress_form, updated_at: InProgressForm::EXPIRES_AFTER.ago - 1.minute)
  end

  describe '#perform' do
    it 'deletes old records' do
      expect { subject.perform }.to change { InProgressForm.count }.from(3).to(2)
      expect { @form_old.reload }.to raise_exception(ActiveRecord::RecordNotFound)
    end
  end
end
