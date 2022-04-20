# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PersonalInformationSerializer do
  subject { serialize(mvi_profile, serializer_class: described_class) }

  let(:mvi_profile) { MPIData.for_user(create(:user, :loa3)).profile }
  let(:attributes) { JSON.parse(subject)['data']['attributes'] }

  context 'when birth_date is nil' do
    before do
      allow(mvi_profile).to receive(:birth_date).and_return(nil)
    end

    it 'returns nil for birth_date' do
      expect(attributes['birth_date']).to eq(nil)
    end
  end
end
