# frozen_string_literal: true

require 'rails_helper'
require 'timecop'

RSpec.describe KmsEncrypted do
  describe KmsEncryptedModelPatch do
    describe '#kms_version' do
      it 'sets version to previous year if before Oct 12 in a given year' do
        Timecop.freeze(Date.new(2023, 7, 4)) do
          rec = UserCredentialEmail.create!(
            credential_email: 'test@test.com',
            user_verification: create(:user_verification)
          )
          expect(rec.encrypted_kms_key).to include('v2022')
        end

        Timecop.return
      end
    end
  end
end
