# frozen_string_literal: true

require 'rails_helper'
require 'rake'

describe 'user_credential rake tasks' do
  let(:user_account) { create(:user_account) }
  let!(:logingov_user_verification) { create(:logingov_user_verification, user_account:) }
  let!(:idme_user_verification) { create(:idme_user_verification, user_account:) }
  let(:type) { 'logingov' }
  let(:credential_id) { logingov_user_verification.credential_identifier }
  let(:requested_by) { 'some-name' }

  before :all do
    Rake.application.rake_require '../rakelib/prod/user_credential'
    Rake::Task.define_task(:environment)
  end

  shared_examples 'credential lock & unlock' do
    describe 'user_credential:lock' do
      let(:task) { Rake::Task['user_credential:lock'] }

      it 'should lock user credential' do
        expect { task.invoke(type, credential_id, requested_by) }
          .to output(/UserCredential::Lock complete - #{type}_uuid: #{credential_id}/).to_stdout
      end
    end
  end

  context 'when the credential type is logingov' do
    it_behaves_like 'credential lock & unlock'
  end
end