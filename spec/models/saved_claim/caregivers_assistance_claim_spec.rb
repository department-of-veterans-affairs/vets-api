# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::CaregiversAssistanceClaim do
  describe '.to_pdf' do
    it 'raises a NotImplementedError' do
      expect { subject.to_pdf }.to raise_error(NotImplementedError)
    end
  end

  describe '.process_attachments!' do
    it 'raises a NotImplementedError' do
      expect { subject.process_attachments! }.to raise_error(NotImplementedError)
    end
  end

  describe '.regional_office' do
    it 'returns empty array' do
      expect(subject.regional_office).to eq([])
    end
  end
end
