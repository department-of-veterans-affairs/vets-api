# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserActionEventsCleanupJob, type: :model do
  let!(:old_user_action_event) { create(:user_action_event, created_at: 2.years.ago) }
  let!(:recent_user_action_event) { create(:user_action_event, created_at: 6.months.ago) }
  let!(:old_user_action) { create(:user_action, user_action_event: old_user_action_event, created_at: 2.years.ago) }
  let!(:recent_user_action) do
    create(:user_action, user_action_event: recent_user_action_event, created_at: 6.months.ago)
  end

  it 'removes user action events older than 1 year' do
    expect { subject.perform }.to change { UserActionEvent.where('created_at < ?', 1.year.ago).count }.to(0)
    expect(model_exists?(old_user_action_event)).to be_falsey
    expect(model_exists?(recent_user_action_event)).to be_truthy
  end

  it 'removes the associated user actions' do
    expect { subject.perform }.to change(UserAction, :count).by(-1)
    expect(model_exists?(old_user_action)).to be_falsey
    expect(model_exists?(recent_user_action)).to be_truthy
  end
end
