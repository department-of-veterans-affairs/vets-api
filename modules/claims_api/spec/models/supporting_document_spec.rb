# frozen_string_literal: true

require 'rails_helper'
require 'support/attr_encrypted_matcher'

RSpec.describe ClaimsApi::SupportingDocument, type: :model do
  describe 'encrypted attribute' do
    it 'should do the thing' do
      expect(subject).to encrypt_attr(:file_data)
    end
  end
end
