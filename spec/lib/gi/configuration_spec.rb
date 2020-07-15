# frozen_string_literal: true

require 'rails_helper'

describe GI::Configuration do
  describe '.open_timeout' do
    context 'when Settings.gi.open_timeout is set' do
      it 'uses the setting' do
        expect(GI::Configuration.instance.open_timeout).to eq(1)
      end
    end
  end

  describe '.read_timeout' do
    context 'when Settings.gi.read_timeout is set' do
      it 'uses the setting' do
        expect(GI::Configuration.instance.read_timeout).to eq(1)
      end
    end
  end
end
