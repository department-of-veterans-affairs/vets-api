# frozen_string_literal: true

require 'rails_helper'
require 'caseflow/configuration'

describe DecisionReview::Configuration do
  describe '.read_timeout' do
    context 'when Settings.caseflow.timeout is set' do
      it 'uses the setting' do
        expect(DecisionReview::Configuration.instance.read_timeout).to eq(119)
      end
    end
  end
end
