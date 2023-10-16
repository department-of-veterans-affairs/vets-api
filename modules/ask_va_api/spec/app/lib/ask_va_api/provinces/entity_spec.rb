# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Provinces::Entity do
  subject(:creator) { described_class }

  let(:info) { { name: 'Colorado', abbreviation: 'CO' } }
  let(:inquiry) { creator.new(info) }

  it 'creates an inquiry' do
    expect(inquiry).to have_attributes({ name: info[:name], abv: info[:abbreviation] })
  end
end
