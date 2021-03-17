# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/communication/service'
require 'va_profile/models/communication_item_group'

describe VAProfile::Communication::Service do
  let(:user) { build(:user, :loa3) }

  subject { described_class.new(user) }

  describe '#communication_items' do
    it 'gets communication items' do
      VCR.use_cassette('va_profile/communication/communication_items', VCR::MATCH_EVERYTHING) do
        res = subject.communication_items

        expect(JSON.parse(res.to_json)).to eq(get_fixture('va_profile/communication_items'))
      end
    end
  end
end
