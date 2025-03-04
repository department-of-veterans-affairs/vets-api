# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserActionsCleanupJob, type: :model do
  let!(:user_action_event) { create(:user_action_event) }
  let!(:old_user_action) { create(:user_action, user_action_event:, created_at: 2.years.ago) }
  let!(:recent_user_action) { create(:user_action, user_action_event:, created_at: 6.months.ago) }

  it 'removes user actions older than 1 year' do
    expect { subject.perform }.to change(UserAction, :count).by(-1)
    expect(model_exists?(old_user_action)).to be_falsey
    expect(model_exists?(recent_user_action)).to be_truthy
  end
end
