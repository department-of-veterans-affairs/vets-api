# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/communication/service'

describe VAProfile::Communication::Service do
  let(:user) { build(:user, :loa3) }

  before do
    allow(user).to receive(:vet360_id).and_return('18277')
  end

  subject { described_class.new(user) }

  describe '#update_communication_permission' do
    context 'without an existing communication permission' do
      it 'posts to communication-permissions', run_at: '2021-03-24T22:38:21Z' do
        VCR.use_cassette('va_profile/communication/post_communication_permissions', VCR::MATCH_EVERYTHING) do
          res = subject.update_communication_permission(build(:communication_item))
          expect(res).to eq(
            {"tx_audit_id"=>"3e776301-4794-402a-8a99-67d473232b6c",
             "status"=>"COMPLETED_SUCCESS",
             "bio"=>
              {"create_date"=>"2021-03-24T22:38:21Z",
               "update_date"=>"2021-03-24T22:38:21Z",
               "tx_audit_id"=>"3e776301-4794-402a-8a99-67d473232b6c",
               "source_system"=>"VETSGOV",
               "source_date"=>"2021-03-24T22:38:21Z",
               "communication_permission_id"=>46,
               "va_profile_id"=>18277,
               "communication_channel_id"=>1,
               "communication_item_id"=>2,
               "communication_channel_name"=>"Text",
               "communication_item_common_name"=>"RX Prescription Refill Reminder",
               "allowed"=>false}}
          )
        end
      end
    end
  end

  describe '#communication_items' do
    it 'gets communication items' do
      VCR.use_cassette('va_profile/communication/communication_items', VCR::MATCH_EVERYTHING) do
        res = subject.communication_items

        expect(JSON.parse(res.to_json)).to eq(get_fixture('va_profile/communication_items'))
      end
    end
  end
end
