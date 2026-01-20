# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/service_response'

RSpec.describe DependentsBenefits::ServiceResponse do
  describe '#initialize' do
    it 'sets status, data, and error' do
      response = described_class.new(status: true, data: { claim: 'data' }, error: 'error message')

      expect(response.status).to be true
      expect(response.data).to eq({ claim: 'data' })
      expect(response.error).to eq('error message')
    end

    it 'defaults data and error to nil' do
      response = described_class.new(status: false)

      expect(response.status).to be false
      expect(response.data).to be_nil
      expect(response.error).to be_nil
    end
  end

  describe '#success?' do
    it 'returns true when status is true' do
      response = described_class.new(status: true)
      expect(response.success?).to be true
    end

    it 'returns false when status is false' do
      response = described_class.new(status: false)
      expect(response.success?).to be false
    end

    it 'returns nil when status is nil' do
      response = described_class.new(status: nil)
      expect(response.success?).to be_nil
    end
  end
end
