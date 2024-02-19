# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Announcements::Entity do
  subject(:creator) { described_class }

  let(:info) do
    {
      Text: 'Test',
      StartDate: '8/18/2023 1:00:00 PM',
      EndDate: '8/18/2023 1:00:00 PM',
      IsPortal: false
    }
  end
  let(:announcement) { creator.new(info) }

  it 'creates an announcement' do
    expect(announcement).to have_attributes({
                                              id: info[:id],
                                              text: info[:Text],
                                              start_date: info[:StartDate],
                                              end_date: info[:EndDate],
                                              is_portal: info[:IsPortal]
                                            })
  end
end
