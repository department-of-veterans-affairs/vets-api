# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::CommunicationPreferencesController, type: :controller do
  let(:user) { build(:user, :loa3) }

  before do
    allow_any_instance_of(User).to receive(:vet360_id).and_return('18277')
    sign_in_as(user)
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
          "data" => {
            "id" => "",
            "type"=>"hashes",
            "attributes"=> {
              "communication_groups" => get_fixture('va_profile/items_and_permissions')
            }
          }
        }
      )
    end
  end
end
