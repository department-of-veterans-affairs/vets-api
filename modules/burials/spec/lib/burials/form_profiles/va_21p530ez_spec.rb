# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Burials::FormProfiles::VA21p530ez, type: :model do
  subject { described_class.new(form_id:, user:) }

  let(:user) { build(:user, :loa3) }
  let(:form_id) { '21P-530EZ' }
  let(:address) { instance_double(Address, country: 'USA') }

  before do
    allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(true)
    allow(FormProfile).to receive(:prefill_enabled_forms).and_return([form_id])
  end

  describe '#metadata' do
    it 'returns correct metadata' do
      expect(subject.metadata).to eq(
        version: 0,
        prefill: true,
        returnUrl: '/claimant-information'
      )

      subject.metadata
    end
  end

  describe '#prefill' do
    it 'initializes identity and contact information' do
      expect(subject.prefill).to match({
                                         form_data: {
                                           'claimantFullName' =>
                                         { 'first' => 'Abraham', 'last' => 'Lincoln', 'suffix' => 'Jr.' },
                                           'claimantAddress' =>
                                         { 'street' => '140 Rock Creek Rd', 'city' => 'Washington', 'state' => 'DC',
                                           'country' => 'USA', 'postalCode' => '20011' },
                                           'claimantPhone' => '3035551234',
                                           'claimantEmail' => kind_of(String)
                                         },
                                         metadata: { version: 0, prefill: true, returnUrl: '/claimant-information' }
                                       })
    end
  end
end
