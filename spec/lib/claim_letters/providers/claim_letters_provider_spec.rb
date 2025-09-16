# frozen_string_literal: true

require 'rails_helper'
require 'claim_letters/providers/claim_letters/claim_letters_provider'

RSpec.describe ClaimLettersProvider do
  # Create a test class that includes the module
  let(:test_class) do
    Class.new do
      include ClaimLettersProvider
    end
  end
  let(:provider) { test_class.new }

  describe '#get_letters' do
    it 'raises NotImplementedError when not implemented' do
      expect { provider.get_letters }.to raise_error(NotImplementedError)
    end
  end

  describe '#get_letter' do
    it 'raises NotImplementedError when not implemented' do
      expect { provider.get_letter('123-456-789') }.to raise_error(NotImplementedError)
    end
  end
end
