# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::States::Entity do
  subject(:creator) { described_class }

  let(:info) { { stateName: 'Colorado', code: 'CO' } }
  let(:inquiry) { creator.new(info) }

  it 'creates an inquiry' do
    expect(inquiry).to have_attributes({ name: info[:stateName], code: info[:code] })
  end
end
