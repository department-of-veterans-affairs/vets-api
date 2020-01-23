# frozen_string_literal: true

require 'rails_helper'

describe GI::Configuration do
  describe '.open_timeout' do
    context 'when Settings.gi.open_timeout is not set' do
      it 'uses the setting' do
        expect(GI::Configuration.instance.open_timeout).to eq(15)
      end
    end

    context 'when Settings.gi.open_timeout is set' do
      it 'uses the setting' do
        stub_const(Settings.gi.open_timeout, 2)
        expect(GI::Configuration.instance.open_timeout).to eq(2)
      end
    end
  end

  describe '.read_timeout' do
    context 'when Settings.gi.read_timeout is not set' do
      it 'uses the setting' do
        expect(GI::Configuration.instance.read_timeout).to eq(15)
      end
    end

    context 'when Settings.gi.read_timeout is set' do
      it 'uses the setting' do
        stub_const(Settings.gi.read_timeout, 2)
        expect(GI::Configuration.instance.read_timeout).to eq(15)
      end
    end
  end
end
