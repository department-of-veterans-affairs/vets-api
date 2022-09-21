# frozen_string_literal: true

require 'rails_helper'

describe VirtualAgentStoreUserInfoJob, type: :job do
  describe '#perform' do
    it 'stores decrypted user info in the database' do
      kms = instance_double(KmsEncrypted::Box)
      allow(kms).to receive(:encrypt).and_return('encrypted_ssn')
      allow(kms).to receive(:decrypt).and_return('decrypted_ssn')

      allow(KmsEncrypted::Box)
        .to receive(:new)
        .and_return(kms)

      record = double
      allow(VirtualAgentUserAccessRecord).to receive(:create) { record }
      allow(record).to receive(:save)

      user_info = { 'first_name' => 'first name', 'last_name' => 'last name', 'ssn' => kms.encrypt('decrypted_ssn'),
                    'icn' => '9876543' }

      VirtualAgentStoreUserInfoJob.new.perform(user_info, 'claims', kms, {})

      expect(kms).to have_received(:decrypt).with('encrypted_ssn')
      expect(VirtualAgentUserAccessRecord).to have_received(:create)
        .with({ action_type: 'claims',
                first_name: 'first name', icn: '9876543', last_name: 'last name', ssn: kms.decrypt('encrypted_ssn') })
      expect(record).to have_received(:save)
    end
  end
end
