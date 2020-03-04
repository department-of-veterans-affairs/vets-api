# frozen_string_literal: true

require 'rails_helper'

describe SentryLogging do
  include SentryLogging

  describe '#set_raven_tag' do
    it 'sets and unset the raven tag' do
      set_raven_tag(:foo, 'bar') do
        expect(Raven.context.tags[:foo]).to eq('bar')
      end
      expect(Raven.context.tags.key?(:foo)).to eq(false)
    end
  end
end
