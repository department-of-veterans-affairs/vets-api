# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::SubTopics::Entity do
  subject(:creator) { described_class }

  let(:info) do
    {
      categoryId: 1,
      id: 1,
      subtopic: 'All other Questions'
    }
  end
  let(:subtopics) { creator.new(info) }

  it 'creates an subtopics' do
    expect(subtopics).to have_attributes({ name: 'All other Questions' })
  end
end
