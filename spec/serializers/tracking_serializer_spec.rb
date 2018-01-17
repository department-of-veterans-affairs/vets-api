# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TrackingSerializer, type: :serializer do
  subject { serialize(tracking, serializer_class: described_class) }

  context 'delivery_service: UPS' do
    let(:tracking) { build(:tracking, delivery_service: 'UPS') }
    it 'should include link' do
      expect(JSON.parse(subject)['data']['links']['tracking_url'])
        .to eq('https://wwwapps.ups.com/WebTracking/track?track=yes&trackNums=01234567890')
    end
  end

  context 'delivery_service: USPS' do
    let(:tracking) { build(:tracking, delivery_service: 'USPS') }
    it 'should include link to USPS' do
      expect(JSON.parse(subject)['data']['links']['tracking_url'])
        .to eq('https://tools.usps.com/go/TrackConfirmAction?tLabels=01234567890')
    end
  end

  context 'delivery_service: other' do
    let(:tracking) { build(:tracking, delivery_service: 'other') }
    it 'should include blank link when not UPS or USPS' do
      expect(JSON.parse(subject)['data']['links']['tracking_url'])
        .to eq('')
    end
  end
end
