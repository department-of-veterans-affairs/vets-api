# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'secure_messaging rake tasks', type: :task do
  before do
    Rake.application.rake_require '../rakelib/secure_messaging'
    Rake::Task.define_task(:environment)
  end

  describe 'sm:setup_test_user' do
    icn = '1234'
    mhv_id = '22336066'
    let(:mhv_id) { mhv_id }
    let(:task) { Rake::Task['sm:setup_test_user'] }
    let(:icn) { icn }

    before do
      task.reenable
      ENV['user_number'] = '210'
      ENV['mhv_id'] = mhv_id
      # rubocop:disable RSpec/MessageChain
      allow(Settings).to receive_message_chain(:betamocks, :cache_dir).and_return('../cache_dir')
      allow(File).to receive(:read).and_return('{"uuid": "f37e9bef73df46a8a0c3f744e8f05185"}')
      allow(MPI::Service).to receive_message_chain(:new, :find_profile_by_identifier)
        .and_return(
          double(
            'profile',
            profile: double(
              'profile',
              icn:
            )
          )
        )
      # rubocop:enable RSpec/MessageChain
    end

    it 'sets up a test user' do
      expect(Rails.cache).to receive(:write).with(
        "mhv_account_creation_#{icn}",
        { champ_va: true,
          message: 'This cache entry was created by rakelib/secure_messaging.rake',
          patient: true,
          premium: true,
          sm_account_created: true,
          user_profile_id: mhv_id },
        expires_in: 1.year
      )
      task.invoke
    end
  end
end
