# frozen_string_literal: true

require 'rails_helper'

describe GI::Configuration do
  let(:config) { GI::Configuration.instance }

  describe '.open_timeout' do
    context 'when Settings.gi.open_timeout is set' do
      it 'uses the setting' do
        expect(config.open_timeout).to eq(1)
      end
    end
  end

  describe '.read_timeout' do
    context 'when Settings.gi.read_timeout is set' do
      it 'uses the setting' do
        expect(config.read_timeout).to eq(1)
      end
    end
  end
end
