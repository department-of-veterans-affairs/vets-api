# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Optionset::Entity do
  subject(:creator) { described_class }

  let(:info) do
    {
      Id: 722_310_182,
      Name: 'Uganda'
    }
  end
  let(:topic) { creator.new(info) }

  it 'creates an topic' do
    expect(topic).to have_attributes({
                                       name: info[:Name]
                                     })
  end
end
