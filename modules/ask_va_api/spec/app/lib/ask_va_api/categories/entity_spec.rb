# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Categories::Entity do
  subject(:creator) { described_class }

  let(:info) { { category: 'VA Health' } }
  let(:inquiry) { creator.new(info) }

  it 'creates an inquiry' do
    expect(inquiry).to have_attributes({ name: 'VA Health' })
  end
end
