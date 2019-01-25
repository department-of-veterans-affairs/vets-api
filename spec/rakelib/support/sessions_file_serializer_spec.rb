# frozen_string_literal: true

require 'rails_helper'
require './rakelib/support/sessions_file_serializer.rb'

describe SessionsFileSerializer do
  describe '#generate_cookies_sessions' do
    context 'with a json file' do
      let(:file) { Rails.root.join('spec', 'support', 'rakelib', 'users_serialized.json') }
      let(:sessions) { JSON.parse(described_class.new(file).generate_cookies_sessions) }

      it 'outputs two sessions' do
        expect(sessions.count).to eq(2)
      end
    end
  end
end
