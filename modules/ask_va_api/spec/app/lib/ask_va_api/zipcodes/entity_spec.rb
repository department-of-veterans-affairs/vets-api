# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Zipcodes::Entity do
  subject(:creator) { described_class }

  let(:info) do
    {
      zip: '36000',
      city: 'Autaugaville',
      state: 'AL',
      lat: 32.4312,
      lng: -86.6549
    }
  end
  let(:subtopics) { creator.new(info) }

  it 'creates an subtopics' do
    expect(subtopics).to have_attributes({ id: nil,
                                           zipcode: info[:zip],
                                           city: info[:city],
                                           state: info[:state],
                                           lat: info[:lat],
                                           lng: info[:lng] })
  end
end
