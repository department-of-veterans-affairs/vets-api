# frozen_string_literal: true

require 'rails_helper'
require 'rake'

describe 'user_credential rake tasks' do # rubocop:disable RSpec/DescribeClass
  let(:user_account) { create(:user_account) }
  let(:icn) { user_account.icn }
  let(:type) { 'logingov' }
  let(:user_verification) { create(:logingov_user_verification, user_account:) }
  let(:linked_user_verification) { create(:idme_user_verification, user_account:) }
  let(:credential_id) { user_verification.credential_identifier }
  let(:requested_by) { 'some-name' }

  before :all do
    Rake.application.rake_require '../rakelib/prod/user_credential'
    Rake::Task.define_task(:environment)
  end

  describe 'user_credential:lock' do
    let(:task) { Rake::Task['user_credential:lock'] }

    before { user_verification.unlock! }

    it 'locks the credential & return the credential type & uuid when successful' do
      expect(user_verification.locked).to be_falsey
      expect { task.invoke(type, credential_id, requested_by) }
        .to output(/UserCredential::Lock complete - #{type}_uuid: #{credential_id}/).to_stdout
      expect(user_verification.reload.locked).to be_truthy
    end
  end

  describe 'user_credential:unlock' do
    let(:task) { Rake::Task['user_credential:unlock'] }

    before { user_verification.lock! }

    it 'unlocks the credential & return the credential type & uuid when successful' do
      expect(user_verification.locked).to be_truthy
      expect { task.invoke(type, credential_id, requested_by) }
        .to output(/UserCredential::Unlock complete - #{type}_uuid: #{credential_id}/).to_stdout
      expect(user_verification.reload.locked).to be_falsey
    end
  end

  describe 'user_credential:lock_all' do
    let(:task) { Rake::Task['user_credential:lock_all'] }

    before do
      user_verification.unlock!
      linked_user_verification.unlock!
    end

    it 'locks all credentials for a user account & return the ICN when successful' do
      expect(user_verification.locked).to be_falsey
      expect(linked_user_verification.locked).to be_falsey
      expect { task.invoke(icn, requested_by) }
        .to output(/UserCredential::LockAll complete - ICN: #{icn}/).to_stdout
      expect(user_verification.reload.locked).to be_truthy
      expect(linked_user_verification.reload.locked).to be_truthy
    end
  end

  describe 'user_credential:unlock_all' do
    let(:task) { Rake::Task['user_credential:unlock_all'] }

    before do
      user_verification.lock!
      linked_user_verification.lock!
    end

    it 'unlocks all credentials for a user account & return the ICN when successful' do
      expect(user_verification.locked).to be_truthy
      expect(linked_user_verification.locked).to be_truthy
      expect { task.invoke(icn, requested_by) }
        .to output(/UserCredential::UnlockAll complete - ICN: #{icn}/).to_stdout
      expect(user_verification.reload.locked).to be_falsey
      expect(linked_user_verification.reload.locked).to be_falsey
    end
  end
end
