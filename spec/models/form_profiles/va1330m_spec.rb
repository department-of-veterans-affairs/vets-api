# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormProfiles::VA1330m do
  subject(:profile) { described_class.new(form_id: '1330M', user: build(:user)) }

  describe '#metadata' do
    it 'returns expected metadata' do
      expect(profile.metadata).to eq({ version: 0, prefill: true, returnUrl: '/applicant-name' })
    end
  end
end
