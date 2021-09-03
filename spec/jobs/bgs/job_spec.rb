# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::Job, type: :job do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:dependency_claim) { create(:dependency_claim) }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674_kitchen_sink) }

  describe '#in_progress_form_copy' do
    it 'returns nil if the in progress form is blank' do
      job = described_class.new

      in_progress_form = job.in_progress_form_copy(nil)
      expect(in_progress_form).to eq(nil)
    end

    it 'returns an object with metadata and formdata' do
      in_progress_form = InProgressForm.new(form_id: '686C-674', user_uuid: user.uuid, form_data: all_flows_payload)
      job = described_class.new

      in_progress_form_copy = job.in_progress_form_copy(in_progress_form)
      expect(in_progress_form_copy.meta_data['expiresAt']).to be_truthy
    end
  end

  describe '#salvage_save_in_progress_form' do
    it 'returns nil if the in progress form is blank' do
      job = described_class.new

      in_progress_form = job.salvage_save_in_progress_form('686C-674', user.uuid, nil)
      expect(in_progress_form).to eq(nil)
    end

    it 'upserts an InProgressForm' do
      in_progress_form = InProgressForm.create!(form_id: '686C-674', user_uuid: user.uuid, form_data: all_flows_payload)
      job = described_class.new

      in_progress_form = job.salvage_save_in_progress_form('686C-674', user.uuid, in_progress_form)
      expect(in_progress_form).to eq(true)
    end
  end
end
