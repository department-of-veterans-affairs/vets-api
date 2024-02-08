# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Optionset::Entity do
  subject(:creator) { described_class }

  let(:info) do
    {
      id: 722_310_182,
      name: 'Uganda'
    }
  end
  let(:topic) { creator.new(info) }

  it 'creates an topic' do
    expect(topic).to have_attributes({
                                       name: info[:name]
                                     })
  end
end
