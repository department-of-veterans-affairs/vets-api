# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Topics::Entity do
  subject(:creator) { described_class }

  let(:info) do
    {
      categoryId: 1,
      id: 1,
      topic: 'All other Questions'
    }
  end
  let(:topics) { creator.new(info) }

  it 'creates an topics' do
    expect(topics).to have_attributes({ name: 'All other Questions' })
  end
end
