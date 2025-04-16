# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::Prescriptions::Client do
  it 'has the expected interface' do
    client = MyHealth::Prescriptions::Client.new(session: { user_id: '123' })
    expect(client).to respond_to(:get_active_rxs)
    expect(client).to respond_to(:get_all_rxs)
    expect(client).to respond_to(:get_rx_details)
    expect(client).to respond_to(:post_refill_rx)
  end
end
