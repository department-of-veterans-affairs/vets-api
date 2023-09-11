# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DebtsApi::V0::Form5655Submission do
  describe 'namespace portability' do
    let!(:some_record) do
      create(:form5655_submission, public_metadata: { 'streamlined' => { 'type' => 'short', 'value' => true } })
    end

    it 'shares data with the old model scope' do
      expect(described_class.last.form).to eq(some_record.form)
      expect(Form5655Submission.last.form).to eq(some_record.form)
    end
  end

  describe 'scopes' do
    let!(:first_record) do
      create(:form5655_submission, public_metadata: { 'streamlined' => { 'type' => 'short', 'value' => true } })
    end
    let!(:second_record) do
      create(:form5655_submission, public_metadata: { 'streamlined' => { 'type' => 'short', 'value' => false } })
    end
    let!(:third_record) { create(:form5655_submission, public_metadata: {}) }
    let!(:fourth_record) do
      create(:form5655_submission, public_metadata: { 'streamlined' => { 'type' => 'short', 'value' => nil } })
    end

    it 'includes records within scope' do
      expect(Form5655Submission.streamlined).to include(first_record)
      expect(Form5655Submission.streamlined.length).to eq(1)

      expect(Form5655Submission.not_streamlined).to include(second_record)
      expect(Form5655Submission.not_streamlined.length).to eq(1)

      expect(Form5655Submission.streamlined_unclear).to include(third_record)
      expect(Form5655Submission.streamlined_unclear.length).to eq(1)

      expect(Form5655Submission.streamlined_nil).to include(fourth_record)
      expect(Form5655Submission.streamlined_nil.length).to eq(1)
    end
  end

  describe '.submit_to_vba' do
    let(:form5655_submission) { create(:debts_api_form5655_submission) }
    let(:guy) { create(:form5655_submission) }

    it 'enqueues a VBA submission job' do
      expect do
        form5655_submission.submit_to_vba
      end.to change(DebtsApi::V0::Form5655::VBASubmissionJob.jobs, :size).by(1)
    end
  end

  describe '.submit_to_vha' do
    let(:form5655_submission) { create(:debts_api_form5655_submission) }

    it 'enqueues a VHA submission job' do
      expect do
        form5655_submission.submit_to_vha
      end.to change(DebtsApi::V0::Form5655::VHASubmissionJob.jobs, :size).by(1)
    end
  end

  describe '.user_cache_id' do
    let(:form5655_submission) { create(:form5655_submission) }
    let(:user) { build(:user, :loa3) }

    it 'creates a new User profile attribute' do
      cache_id = form5655_submission.user_cache_id
      attributes = UserProfileAttributes.find(cache_id)
      expect(attributes.class).to eq(UserProfileAttributes)
      expect(attributes.icn).to eq(user.icn)
    end

    context 'with stale user id' do
      before do
        form5655_submission.user_uuid = '00000'
      end

      it 'returns an error' do
        expect { form5655_submission.user_cache_id }.to raise_error(Form5655Submission::StaleUserError)
      end
    end
  end
end
