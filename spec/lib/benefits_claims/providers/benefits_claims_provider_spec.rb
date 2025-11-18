# frozen_string_literal: true

require 'rails_helper'
require 'benefits_claims/providers/benefits_claims/benefits_claims_provider'

RSpec.describe BenefitsClaimsProvider do
  let(:test_class) do
    Class.new do
      include BenefitsClaimsProvider
    end
  end
  let(:provider) { test_class.new }

  describe '#get_claims' do
    it 'raises NotImplementedError when not implemented' do
      expect { provider.get_claims }.to raise_error(NotImplementedError)
    end
  end

  describe '#get_claim' do
    it 'raises NotImplementedError when not implemented' do
      expect { provider.get_claim('123456') }.to raise_error(NotImplementedError)
    end
  end
end

