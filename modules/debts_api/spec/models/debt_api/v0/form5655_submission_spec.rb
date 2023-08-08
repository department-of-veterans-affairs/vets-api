# frozen_string_literal: true

require 'pry'
require 'rails_helper'

RSpec.describe DebtsApi::V0::Form5655Submission do
  describe '.submit_to_vba' do
    let(:form5655_submission) { create(:debts_api_form5655_submission) }
    let(:guy) { create(:form5655_submission) }

    it 'enqueues a VBA submission job' do
      expect { form5655_submission.submit_to_vba }.to change(DebtsApi::V0::Form5655::VBASubmissionJob.jobs, :size).by(1)
    end
  end

  describe '.submit_to_vha' do
    let(:form5655_submission) { create(:debts_api_form5655_submission) }

    it 'enqueues a VHA submission job' do
      expect { form5655_submission.submit_to_vha }.to change(DebtsApi::V0::Form5655::VHASubmissionJob.jobs, :size).by(1)
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
