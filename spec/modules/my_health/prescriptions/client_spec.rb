# frozen_string_literal: true

require 'rails_helper'
require 'my_health/prescriptions/client'

RSpec.describe MyHealth::Prescriptions::Client do
  let(:client) { described_class.new(session: { user_id: '123' }) }

  it 'has the correct service name for metrics' do
    config = MyHealth::Prescriptions::Configuration.instance
    expect(config.service_name).to eq('MyHealth-Prescriptions')
  end

  it 'inherits from Common::Client::Base' do
    expect(described_class.ancestors).to include(Common::Client::Base)
  end
end
