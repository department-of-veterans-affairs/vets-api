# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormProfiles::VA8794 do
  subject(:profile) { described_class.new(form_id: '22-8794', user: build(:user)) }

  describe '#metadata' do
    it 'returns expected metadata' do
      expect(profile.metadata).to eq({ version: 0, prefill: true, returnUrl: '/applicant/information' })
    end
  end
end
