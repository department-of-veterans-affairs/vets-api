# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Announcements::Serializer do
  let(:info) do
    {
      Text: 'Test',
      StartDate: '8/18/2023 1:00:00 PM',
      EndDate: '8/18/2023 1:00:00 PM',
      IsPortal: false
    }
  end
  let(:announcement) { AskVAApi::Announcements::Entity.new(info) }
  let(:response) { described_class.new(announcement) }
  let(:expected_response) do
    { data: { id: nil,
              type: :announcements,
              attributes: {
                text: info[:Text],
                start_date: info[:StartDate],
                end_date: info[:EndDate],
                is_portal: info[:IsPortal]
              } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
