# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

describe Mobile::V0::Profile::SynchronousUpdateService do
  let(:user) { FactoryBot.build(:iam_user) }
  let(:service) { Mobile::V0::Profile::SynchronousUpdateService.new(user) }

  before { iam_sign_in(user) }
  
  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }
  
  before do
    iam_sign_in
    # allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    # Timecop.freeze(Time.zone.parse('2020-11-01T10:30:00Z'))
  end
  
  # after { Timecop.return }
  
  describe '#save_and_await_response' do
    let(:params) { build(:vet360_address, vet360_id: user.vet360_id, validation_key: nil) }
    
    context 'when an update succeeds and the transaction response returns immediately' do
      let(:response) do
        VCR.use_cassette('profile/put_address_success') do
          VCR.use_cassette('profile/address_transaction_status') do
            service.save_and_await_response(resource_type: :address, params: params, update: true)
          end
        end
      end
      
      it 'returns a 200 for the VA response' do
        expect(response.status).to eq(200)
      end
    end
  end
end
