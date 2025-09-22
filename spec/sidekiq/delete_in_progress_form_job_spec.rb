# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeleteInProgressFormJob, type: :job do
  subject { described_class.new }

  let(:current_user) { build(:user, :loa3) }
  let(:form_id) { '1010ez' }
  let!(:in_progress_form) do
    create(:in_progress_form, form_id:, user_uuid: current_user.uuid)
  end

  let(:log_expectation_meta) { "[#{form_id}][user_uuid:#{current_user.uuid}]" }
  let(:log_expectation_success) { 'InProgressForm successfully deleted: true' }
  let(:log_expectation_failure) { 'InProgressForm successfully deleted: false' }

  describe '#perform' do
    context 'when current_user exists' do
      context 'and has an in-progress form' do
        it 'deletes the in-progress form' do
          expect(Rails.logger).to receive(:info).with(
            "#{log_expectation_meta}[ipf_id_before:#{in_progress_form.id}, ipf_id_after:] - #{log_expectation_success}"
          )

          expect do
            subject.perform(form_id, current_user.uuid)
          end.to change(InProgressForm, :count).by(-1)

          expect(InProgressForm.form_for_user(form_id, current_user)).to be_nil
        end

        it 'logs the deletion process with correct IDs' do
          expect(Rails.logger).to receive(:info).with(
            "#{log_expectation_meta}[ipf_id_before:#{in_progress_form.id}, ipf_id_after:] - #{log_expectation_success}"
          )

          subject.perform(form_id, current_user.uuid)
        end
      end

      context 'and no in-progress form' do
        before { in_progress_form.destroy }

        it 'does not raise an error' do
          expect(Rails.logger).to receive(:info).with(
            "#{log_expectation_meta}[ipf_id_before:, ipf_id_after:] - #{log_expectation_success}"
          )

          expect { subject.perform(form_id, current_user.uuid) }.not_to raise_error
        end
      end
    end

    context 'when user_uuid is nil' do
      it 'does not attempt to delete and logs appropriately' do
        expect { subject.perform(form_id, nil) }.not_to change(InProgressForm, :count)
      end
    end

    context 'all forms are not deleted' do
      before do
        allow(InProgressForm).to receive(:find_by)
          .with({ form_id: '1010ez', user_uuid: current_user.uuid })
          .and_return(in_progress_form, nil, in_progress_form)
      end

      it 'logs that the second was not deleted' do
        in_progress_meta = "[ipf_id_before:#{in_progress_form.id}, ipf_id_after:#{in_progress_form.id}]"
        expect(Rails.logger).to receive(:info).with(
          "#{log_expectation_meta}#{in_progress_meta} - #{log_expectation_failure}"
        )

        subject.perform(form_id, current_user.uuid)
      end
    end
  end

  describe 'sidekiq configuration' do
    it 'has retry configured' do
      expect(described_class.sidekiq_options_hash['retry']).to eq(5)
    end
  end
end
