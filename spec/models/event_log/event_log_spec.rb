# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventLog::Log, type: :model do
  it 'can persist an event log' do
    expect { EventLog::Log.create(request_id: SecureRandom.uuid) }
      .to change { EventLog::Log.count }.from(0).to(1)
  end
end
