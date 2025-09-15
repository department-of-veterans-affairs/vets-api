# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeleteInProgressFormJob, type: :job do
  subject { described_class.new }

  let(:current_user) { build(:user, :loa3) }
  let(:form_id) { '1010ez' }
  let!(:in_progress_form) do
    create(:in_progress_form, form_id:, user_uuid: current_user.uuid)
  end

  describe '#perform' do
    context 'when current_user exists' do
      context 'and has an in-progress form' do
        it 'deletes the in-progress form' do
          expect(Rails.logger).to receive(:info).with(
            "[10-10EZ][user_uuid:#{current_user.uuid}][ipf_id_before:#{in_progress_form.id}, ipf_id_after:] - " \
            'InProgressForm successfully deleted: true'
          )

          expect do
            subject.perform(form_id, current_user)
          end.to change(InProgressForm, :count).by(-1)

          expect(InProgressForm.form_for_user(form_id, current_user)).to be_nil
        end

        it 'logs the deletion process with correct IDs' do
          logger_regex = [
            /\[10-10EZ\]/,
            /\[user_uuid:#{current_user.uuid}\]/,
            /\[ipf_id_before:\d+,ipf_id_after:\d+\]/,
            / - InProgressForm successfully deleted: true/
          ]

          expect(Rails.logger).to receive(:info).with(
            a_string_matching(Regexp.union(logger_regex))
          )

          subject.perform(form_id, current_user)
        end
      end

      context 'and no in-progress form' do
        before { in_progress_form.destroy }

        it 'does not raise an error' do
          logger_regex = [
            /\[10-10EZ\]/,
            /\[user_uuid:#{current_user.uuid}\]/,
            /\[ipf_id_before:,ipf_id_after:]/,
            / - InProgressForm successfully deleted: true/
          ]

          expect(Rails.logger).to receive(:info).with(
            a_string_matching(Regexp.union(logger_regex))
          )

          expect { subject.perform(form_id, current_user) }.not_to raise_error
        end
      end
    end

    context 'when current_user is nil' do
      it 'does not attempt to delete and logs appropriately' do
        expect { subject.perform(form_id, nil) }.not_to change(InProgressForm, :count)
      end
    end

    context 'two In Progress Forms exist' do
      before do
        allow(InProgressForm).to receive(:form_for_user)
          .with('1010ez', anything)
          .and_return(in_progress_form, in_progress_form)
      end

      it 'logs that the second was not deleted' do
        logger_regex = [
          /\[10-10EZ\]/,
          /\[user_uuid:#{current_user.uuid},user_account_id:none\]/,
          /\[health_care_application_id:\d+\]/,
          /\[ipf_id_before:\d+,ipf_id_after:\d+\]/,
          / - InProgressForm successfully deleted: false/
        ]

        expect(Rails.logger).to receive(:info).with(
          a_string_matching(Regexp.union(logger_regex))
        )

        subject.perform(form_id, current_user)
      end
    end
  end

  describe 'sidekiq configuration' do
    it 'has retry configured' do
      expect(described_class.sidekiq_options_hash['retry']).to eq(5)
    end
  end
end
