# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

RSpec.describe Mobile::V0::Vet360LinkingJob, type: :job do
  before { iam_sign_in(FactoryBot.build(:iam_user, :no_vet360_id)) }
  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }
  let(:user) { FactoryBot.build(:iam_user, :no_vet360_id) }

  it 'Returns a completed transaction for linking an account with vet360' do
    VCR.use_cassette('profile/init_vet360_id_status_complete') do
      VCR.use_cassette('profile/init_vet360_id_status_incomplete') do
        VCR.use_cassette('profile/init_vet360_id_success') do
          result = described_class.new.perform(user)
          expect(result.transaction_status).to eq('COMPLETED_SUCCESS')
        end
      end
    end
  end
end
