# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormProfiles::VA214138 do
  subject(:profile) { described_class.new(form_id: '21-4138', user:) }

  let(:user) { create(:user, :loa3) }

  describe '#metadata' do
    it 'returns expected metadata' do
      expect(profile.metadata).to eq({
                                       version: 0,
                                       prefill: true,
                                       returnUrl: '/statement-type'
                                     })
    end
  end

  describe '#prefill' do
    it 'prefills the veteran SSN from identity information' do
      data = profile.prefill
      expect(data[:form_data]['veteran']['ssn']).to eq(user.ssn_normalized)
    end
  end
end
