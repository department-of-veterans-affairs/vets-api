# frozen_string_literal: true

require 'rails_helper'
require 'support/attr_encrypted_matcher'

RSpec.describe ClaimsApi::AutoEstablishedClaim, type: :model do
  let(:auto_form) { build(:auto_established_claim, auth_headers: { some: 'data' }) }

  describe 'encrypted attributes' do
    it 'should do the thing' do
      expect(subject).to encrypt_attr(:form_data)
      expect(subject).to encrypt_attr(:auth_headers)
    end
  end
end
