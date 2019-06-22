# frozen_string_literal: true

require 'rails_helper'

describe Vsp::Service do
  describe '.get_message' do
    context 'with a 200 response' do
      it 'creates a message object' do
        VCR.use_cassette('vsp/get_message') do
          message = subject.get_message
          expect(message.message).to eq('Welcome to the vets.gov API')
        end
      end
    end
  end
end
