# frozen_string_literal: true

require 'rails_helper'

describe VAForms::Slack::HashNotification do
  describe '#message_text' do
    let(:params) do
      {
        'test_key' => 'test_value',
        'args' => %w[1234 5678],
        'gibberish' => 2,
        'indeed' => 'indeed gibberish',
        'message' => 'Something happened here'
      }
    end

    it 'returns the VSP environment' do
      with_settings(Settings, vsp_environment: 'staging') do
        expect(
          described_class.new(params).message_text
        ).to include('ENVIRONMENT: :construction: staging :construction:')
      end
    end

    it 'displays all the keys capitalized and formatted' do
      with_settings(Settings, vsp_environment: 'staging') do
        expect(described_class.new(params).message_text).to include(
          "\nTEST_KEY : test_value\nARGS : [\"1234\", \"5678\"]
GIBBERISH : 2\nINDEED : indeed gibberish\nMESSAGE : Something happened here"
        )
      end
    end
  end
end
