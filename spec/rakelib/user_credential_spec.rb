# frozen_string_literal: true

require 'rails_helper'
require 'rake'

describe 'user_credential rake tasks' do # rubocop:disable RSpec/DescribeClass
  let(:user_account) { create(:user_account) }
  let(:icn) { user_account.icn }
  let(:user_verification) { create(:logingov_user_verification, user_account:) }
  let(:type) { user_verification.credential_type }
  let(:credential_id) { user_verification.credential_identifier }
  let(:linked_user_verification) { create(:idme_user_verification, user_account:) }
  let(:linked_type) { linked_user_verification.credential_type }
  let(:linked_credential_id) { linked_user_verification.credential_identifier }
  let(:requested_by) { 'some-name' }

  before :all do
    Rake.application.rake_require '../rakelib/prod/user_credential'
    Rake::Task.define_task(:environment)
  end

  context 'argument validations' do
    let(:task) { Rake::Task['user_credential:lock'] }

    before { task.reenable }

    context 'when a required argument is missing' do
      let(:expected_output) { '[UserCredential::Lock] failed - Missing required arguments' }

      it 'raises an error' do
        expect { task.invoke }.to output("#{expected_output}\n").to_stdout
      end
    end

    context 'rwhen type argument is invalid' do
      let(:expected_output) { '[UserCredential::Lock] failed - Invalid type' }

      it 'raises an error' do
        expect { task.invoke('invalid', credential_id, requested_by) }.to output("#{expected_output}\n").to_stdout
      end
    end
  end

  context 'single credential changes' do
    let(:expected_output) do
      "#{namespace} rake task start, context: {\"type\":\"#{type}\",\"credential_id\":\"#{credential_id}\"," \
        "\"requested_by\":\"#{requested_by}\"}\n" \
        "#{namespace} credential #{action}, context: {\"type\":\"#{type}\",\"credential_id\":\"#{credential_id}\"," \
        "\"requested_by\":\"#{requested_by}\",\"locked\":#{locked}}\n" \
        "#{namespace} rake task complete, context: {\"type\":\"#{type}\",\"credential_id\":\"#{credential_id}\"," \
        "\"requested_by\":\"#{requested_by}\"}\n"
    end

    describe 'user_credential:lock' do
      let(:task) { Rake::Task['user_credential:lock'] }
      let(:namespace) { '[UserCredential::Lock]' }
      let(:action) { 'lock' }
      let(:locked) { true }

      before do
        user_verification.unlock!
        task.reenable
      end

      it 'locks the credential & return the credential type & uuid when successful' do
        expect(user_verification.locked).to be_falsey
        expect { task.invoke(type, credential_id, requested_by) }.to output(expected_output).to_stdout
        expect(user_verification.reload.locked).to be_truthy
      end
    end

    describe 'user_credential:unlock' do
      let(:task) { Rake::Task['user_credential:unlock'] }
      let(:namespace) { '[UserCredential::Unlock]' }
      let(:action) { 'unlock' }
      let(:locked) { false }

      before { user_verification.lock! }

      it 'unlocks the credential & return the credential type & uuid when successful' do
        expect(user_verification.locked).to be_truthy
        expect { task.invoke(type, credential_id, requested_by) }.to output(expected_output).to_stdout
        expect(user_verification.reload.locked).to be_falsey
      end
    end
  end

  context 'account-wide credential changes' do
    let(:expected_output) do
      [
        "#{namespace} rake task start, context: {\"icn\":\"#{icn}\",\"requested_by\":\"#{requested_by}\"}",
        "#{namespace} credential #{action}, context: {\"icn\":\"#{icn}\",\"requested_by\":\"#{requested_by}\"," \
        "\"type\":\"#{type}\",\"credential_id\":\"#{credential_id}\",\"locked\":#{locked}}",
        "#{namespace} credential #{action}, context: {\"icn\":\"#{icn}\",\"requested_by\":\"#{requested_by}\"," \
        "\"type\":\"#{linked_type}\",\"credential_id\":\"#{linked_credential_id}\",\"locked\":#{locked}}",
        "#{namespace} rake task complete, context: {\"icn\":\"#{icn}\",\"requested_by\":\"#{requested_by}\"}"
      ].sort
    end

    describe 'user_credential:lock_all' do
      let(:task) { Rake::Task['user_credential:lock_all'] }
      let(:namespace) { '[UserCredential::LockAll]' }
      let(:action) { 'lock' }
      let(:locked) { true }

      before do
        user_verification.unlock!
        linked_user_verification.unlock!
      end

      it 'locks all credentials for a user account & return the ICN when successful' do
        sorted_output = []

        expect do
          task.invoke(icn, requested_by)
          sorted_output = $stdout.string.split("\n").map(&:strip).sort
        end.to output.to_stdout

        expect(sorted_output).to eq(expected_output)
        expect(user_verification.reload.locked).to be_truthy
        expect(linked_user_verification.reload.locked).to be_truthy
      end
    end

    describe 'user_credential:unlock_all' do
      let(:task) { Rake::Task['user_credential:unlock_all'] }
      let(:namespace) { '[UserCredential::UnlockAll]' }
      let(:action) { 'unlock' }
      let(:locked) { false }

      before do
        user_verification.lock!
        linked_user_verification.lock!
      end

      it 'unlocks all credentials for a user account & return the ICN when successful' do
        sorted_output = []

        expect do
          task.invoke(icn, requested_by)
          sorted_output = $stdout.string.split("\n").map(&:strip).sort
        end.to output.to_stdout

        expect(sorted_output).to eq(expected_output)
        expect(user_verification.reload.locked).to be_falsey
        expect(linked_user_verification.reload.locked).to be_falsey
      end
    end
  end
end
