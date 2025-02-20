# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InProgressFormCleaner do
  describe '#perform' do
    let(:now) { Time.now.utc }

    context 'when there is a set of records' do
      before do
        Timecop.freeze(now - 61.days)
        @form_expired = create(:in_progress_form)
        Timecop.freeze(now - 59.days)
        @form_active = create(:in_progress_form)
        Timecop.freeze(now)
        @form_new = create(:in_progress_form)
        Timecop.return
      end

      it 'deletes old records' do
        expect { subject.perform }.to change(InProgressForm, :count).by(-1)
        expect { @form_expired.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      end
    end

    context 'when there is a form526 record older than 60 days' do
      before do
        Timecop.freeze(now - 61.days)
        @form526_active = create(:in_progress_526_form)
        Timecop.return
      end

      it 'does not delete the record' do
        expect { subject.perform }.not_to change(InProgressForm, :count)
        expect { @form526_active.reload }.not_to raise_exception
      end
    end

    context 'when there is a form526 record older than 365 days' do
      before do
        Timecop.freeze(now - 366.days)
        @form526_expired = create(:in_progress_526_form)
        Timecop.return
      end

      it 'deletes the record' do
        expect { subject.perform }.to change(InProgressForm, :count).by(-1)
        expect { @form526_expired.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      end
    end
  end
end
