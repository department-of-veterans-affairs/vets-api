# frozen_string_literal: true

require 'rails_helper'

describe Vet360::Models::Base do
  describe 'validation' do

    let(:email) { build(:email) }

    it 'ensures effectiveEndDate is in the past', aggregate_failures: true do
      expect(email.valid?).to eq(true)
      email.effective_end_date = (Time.zone.now + 1.minute).iso8601
      expect(email.valid?).to eq(false)
      email.effective_end_date = Time.zone.now.iso8601
      expect(email.valid?).to eq(true)
    end
  end
end
