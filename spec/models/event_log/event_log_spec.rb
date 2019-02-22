# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventLog, type: :model do
  it 'can persist an event log' do
    expect { EventLog::EventLog.create(request_id: SecureRandom.uuid) }
      .to change { EventLog::EventLog.count }.from(0).to(1)
  end
end
