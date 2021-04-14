# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::CommunicationPreferencesController, type: :controller do
  let(:user) { build(:user, :loa3) }

  let(:valid_params) do
    {
      communication_item: {
        id: 2,
        communication_channels: [
          {
            id: 1,
            communication_permission: {
              allowed: true
            }
          }
        ]
      }
    }
  end

  before do
    allow_any_instance_of(User).to receive(:vet360_id).and_return('18277')
    sign_in_as(user)
  end

  def self.test_invalid_req
    context 'with invalid params' do
      let(:params) do
        {
          communication_item: {
            foo: true
          }
        }
      end

      it 'returns validation error' do
        subject

        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)['errors'][0]['title']).to eq("Id can't be blank")
      end
    end
  end

  describe '#update_all' do
    let(:valid_params) do
      {
        communication_items: [
          {
            communication_item: {
              id: 3,
              communication_channels: [
                {
                  id: 1,
                  communication_permission: {
                    id: 342,
                    allowed: true
                  }
                }
              ]
            }
          },
          {
            communication_item: {
              id: 2,
              communication_channels: [
                {
                  id: 1,
                  communication_permission: {
                    id: 341,
                    allowed: true
                  }
                }
              ]
            }
          },
          {
            communication_item: {
              id: 4,
              communication_channels: [
                {
                  id: 1,
                  communication_permission: {
                    id: 729,
                    allowed: true
                  }
                }
              ]
            }
          },
          {
            communication_item: {
              id: 5,
              communication_channels: [
                {
                  id: 2,
                  communication_permission: {
                    allowed: true
                  }
                }
              ]
            }
          },
        ]
      }
    end

    subject do
      put(
        :update_all,
        params: valid_params,
        as: :json
      )
    end

    before do
      allow_any_instance_of(User).to receive(:vet360_id).and_return('16445')
    end

    it 'updates multiple communication permissions', run_at: '2021-04-13T20:54:58Z' do
      VCR.use_cassette('va_profile/communication/update_all_communication_permissions', VCR::MATCH_EVERYTHING) do
        subject

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq(
          {"tx_audit_id"=>"4e3ae638-4269-4d10-8fbc-71b10872d774",
           "status"=>"COMPLETED_SUCCESS",
           "bio"=>
            {"create_date"=>"2021-04-02T22:25:25Z",
             "update_date"=>"2021-04-02T22:25:25Z",
             "tx_audit_id"=>"bc6b2c88-98d6-4e20-b15b-5c746789d7ed",
             "source_system"=>"VETSGOV",
             "source_date"=>"2021-04-02T22:25:24Z",
             "va_profile_id"=>16445,
             "communication_permissions"=>
              [{"create_date"=>"2021-04-12T15:21:52Z",
                "update_date"=>"2021-04-13T20:54:59Z",
                "tx_audit_id"=>"4e3ae638-4269-4d10-8fbc-71b10872d774",
                "source_system"=>"VETSGOV",
                "source_date"=>"2021-04-13T20:54:58Z",
                "communication_permission_id"=>729,
                "va_profile_id"=>16445,
                "communication_channel_id"=>1,
                "communication_item_id"=>4,
                "communication_channel_name"=>"Text",
                "communication_item_common_name"=>"Form 22-1990 Submission Confirmation",
                "allowed"=>true},
               {"create_date"=>"2021-04-13T20:54:59Z",
                "update_date"=>"2021-04-13T20:54:59Z",
                "tx_audit_id"=>"4e3ae638-4269-4d10-8fbc-71b10872d774",
                "source_system"=>"VETSGOV",
                "source_date"=>"2021-04-13T20:54:58Z",
                "communication_permission_id"=>770,
                "va_profile_id"=>16445,
                "communication_channel_id"=>2,
                "communication_item_id"=>5,
                "communication_channel_name"=>"Email",
                "communication_item_common_name"=>"Form 526-EZ Submission Confirmation",
                "allowed"=>true},
               {"create_date"=>"2021-04-02T22:25:25Z",
                "update_date"=>"2021-04-13T20:54:59Z",
                "tx_audit_id"=>"4e3ae638-4269-4d10-8fbc-71b10872d774",
                "source_system"=>"VETSGOV",
                "source_date"=>"2021-04-13T20:54:58Z",
                "communication_permission_id"=>341,
                "va_profile_id"=>16445,
                "communication_channel_id"=>1,
                "communication_item_id"=>2,
                "communication_channel_name"=>"Text",
                "communication_item_common_name"=>"RX Prescription Refill Reminder",
                "allowed"=>true},
               {"create_date"=>"2021-04-02T22:25:25Z",
                "update_date"=>"2021-04-13T20:54:59Z",
                "tx_audit_id"=>"4e3ae638-4269-4d10-8fbc-71b10872d774",
                "source_system"=>"VETSGOV",
                "source_date"=>"2021-04-13T20:54:58Z",
                "communication_permission_id"=>342,
                "va_profile_id"=>16445,
                "communication_channel_id"=>1,
                "communication_item_id"=>3,
                "communication_channel_name"=>"Text",
                "communication_item_common_name"=>"Scheduled Appointment Confirmation",
                "allowed"=>true}]}}
        )
      end
    end
  end

  describe '#update' do
    subject do
      patch(
        :update,
        params: params.merge(id: 46),
        as: :json
      )
    end

    let(:params) do
      valid_params
    end

    test_invalid_req

    it 'updates a communication_permission', run_at: '2021-03-24T23:46:17Z' do
      VCR.use_cassette('va_profile/communication/put_communication_permissions', VCR::MATCH_EVERYTHING) do
        subject

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq(
          { 'tx_audit_id' => '924b24a5-609d-48ff-ab2e-9f5ac8770e93',
            'status' => 'COMPLETED_SUCCESS',
            'bio' =>
            { 'create_date' => '2021-03-24T22:38:21Z',
              'update_date' => '2021-03-24T23:46:17Z',
              'tx_audit_id' => '924b24a5-609d-48ff-ab2e-9f5ac8770e93',
              'source_system' => 'VETSGOV',
              'source_date' => '2021-03-24T23:46:17Z',
              'communication_permission_id' => 46,
              'va_profile_id' => 18_277,
              'communication_channel_id' => 1,
              'communication_item_id' => 2,
              'communication_channel_name' => 'Text',
              'communication_item_common_name' => 'RX Prescription Refill Reminder',
              'allowed' => true } }
        )
      end
    end
  end

  describe '#create' do
    subject do
      post(
        :create,
        params: params,
        as: :json
      )
    end

    let(:params) { valid_params }

    test_invalid_req

    it 'creates a communication permission', run_at: '2021-03-24T22:38:21Z' do
      VCR.use_cassette('va_profile/communication/post_communication_permissions', VCR::MATCH_EVERYTHING) do
        params[:communication_item][:communication_channels][0][:communication_permission][:allowed] = false

        subject

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq(
          { 'tx_audit_id' => '3e776301-4794-402a-8a99-67d473232b6c',
            'status' => 'COMPLETED_SUCCESS',
            'bio' =>
            { 'create_date' => '2021-03-24T22:38:21Z',
              'update_date' => '2021-03-24T22:38:21Z',
              'tx_audit_id' => '3e776301-4794-402a-8a99-67d473232b6c',
              'source_system' => 'VETSGOV',
              'source_date' => '2021-03-24T22:38:21Z',
              'communication_permission_id' => 46,
              'va_profile_id' => 18_277,
              'communication_channel_id' => 1,
              'communication_item_id' => 2,
              'communication_channel_name' => 'Text',
              'communication_item_common_name' => 'RX Prescription Refill Reminder',
              'allowed' => false } }
        )
      end
    end
  end

  describe '#index' do
    it 'returns the right data' do
      VCR.use_cassette('va_profile/communication/get_communication_permissions', VCR::MATCH_EVERYTHING) do
        VCR.use_cassette('va_profile/communication/communication_items', VCR::MATCH_EVERYTHING) do
          get(:index)
        end
      end

      expect(response.status).to eq(200)

      expect(JSON.parse(response.body)).to eq(
        {
          'data' => {
            'id' => '',
            'type' => 'hashes',
            'attributes' => {
              'communication_groups' => get_fixture('va_profile/items_and_permissions')
            }
          }
        }
      )
    end
  end
end
