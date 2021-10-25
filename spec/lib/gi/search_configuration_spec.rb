# frozen_string_literal: true

require 'rails_helper'
require 'gi/search_configuration'

describe GI::SearchConfiguration do
  describe '.open_timeout' do
    context 'when Settings.gi.search.open_timeout is not set' do
      it 'uses the setting' do
        expect(GI::SearchConfiguration.instance.open_timeout).to eq(2)
      end
    end
  end

  describe '.read_timeout' do
    context 'when Settings.gi.search.read_timeout is not set' do
      it 'uses the setting' do
        expect(GI::SearchConfiguration.instance.read_timeout).to eq(2)
      end
    end
  end
end
