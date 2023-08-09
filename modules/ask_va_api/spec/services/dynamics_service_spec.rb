# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DynamicsService do
  subject(:service) { described_class.new }

  let(:submitter) { service.get_submitter_inquiries(uuid: '6400bbf301eb4e6e95ccea7693eced6f') }

  it 'returns submitter_inquiries' do
    expect(submitter.inquiries).to be_an(Array)
  end
end
