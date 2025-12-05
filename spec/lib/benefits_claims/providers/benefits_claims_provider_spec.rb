# frozen_string_literal: true

require 'rails_helper'
require 'benefits_claims/providers/benefits_claims/benefits_claims_provider'
require 'support/benefits_claims/benefits_claims_provider'

RSpec.describe BenefitsClaimsProvider do
  subject { test_class.new(current_user) }

  let(:test_class) do
    Class.new do
      include BenefitsClaimsProvider

      def initialize(_current_user); end
    end
  end
  let(:current_user) { build(:user) }

  it_behaves_like 'benefits claims provider'

  describe '#get_claims' do
    it 'raises NotImplementedError when not implemented' do
      expect { subject.get_claims }.to raise_error(NotImplementedError)
    end
  end

  describe '#get_claim' do
    it 'raises NotImplementedError when not implemented' do
      expect { subject.get_claim('123456') }.to raise_error(NotImplementedError)
    end
  end
end
