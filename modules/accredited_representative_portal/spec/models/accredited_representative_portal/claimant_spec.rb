# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe Claimant, type: :model do
    let(:icn) { '1234567890V123456' }
    let(:poa_code) { '008' }
    let(:wrong_poa_code) { '999' }
    let(:representative_name) { 'Trustworthy Organization' }

    let(:profile) do
      instance_double(
        'MPI::Models::MviProfile',
        icn: icn,
        given_names: ['John'],
        family_name: 'Doe',
        address: instance_double('Address', city: 'Somewhere', state: 'VA', postal_code: '12345')
      )
    end

    let(:poa_requests) { [] }

    let(:poa_lookup_service) do
      instance_double(
        PoaLookupService,
        claimant_poa_code: poa_code,
        representative_name: representative_name
      )
    end

    before do
      allow(PoaLookupService).to receive(:new).with(icn).and_return(poa_lookup_service)
    end

    context 'when active_poa_codes includes claimant_poa_code' do
      subject { described_class.new(profile, poa_requests, [poa_code]) }

      it 'returns the representative name' do
        expect(subject.representative).to eq(representative_name)
      end
    end

    context 'when active_poa_codes does NOT include claimant_poa_code' do
      subject { described_class.new(profile, poa_requests, [wrong_poa_code]) }

      it 'returns nil' do
        expect(subject.representative).to be_nil
      end
    end
  end
end
