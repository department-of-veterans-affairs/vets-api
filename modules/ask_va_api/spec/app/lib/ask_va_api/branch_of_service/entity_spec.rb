# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::BranchOfService::Entity do
  subject(:creator) { described_class }

  let(:info) { { code: 'USMA', description: 'US Military Academy' } }
  let(:service) { creator.new(info) }

  it 'creates an topic' do
    expect(service).to have_attributes({ id: nil, code: info[:code], description: info[:description] })
  end
end
