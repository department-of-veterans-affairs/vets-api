# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::BaseAssertionValidator do
  subject(:base_validator) { described_class.new }

  describe 'abstract method enforcement' do
    it 'raises NotImplementedError for abstract methods' do
      %i[
        attributes_error_class
        signature_mismatch_error_class
        expired_error_class
        malformed_error_class
        active_certs
      ].each do |method_name|
        expect { base_validator.send(method_name) }
          .to raise_error(NotImplementedError), "expected #{method_name} to be abstract"
      end
    end
  end
end
