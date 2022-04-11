# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::SupplementalClaim, type: :model do
  include FixtureHelpers

  context 'headers' do
    let(:auth_headers) { fixture_as_json 'valid_200995_headers.json', version: 'v2' }
    let(:supplemental_claim) { create(:supplemental_claim) }

    describe 'veteran_first_name' do
      it { expect(supplemental_claim.veteran_first_name).to eq(auth_headers['X-VA-First-Name']) }
    end

    describe 'veteran_middle_initial' do
      it { expect(supplemental_claim.veteran_middle_initial).to eq(auth_headers['X-VA-Middle-Initial']) }
    end

    describe 'veteran_last_name' do
      it { expect(supplemental_claim.veteran_last_name).to eq(auth_headers['X-VA-Last-Name']) }
    end

    describe 'full_name' do
      it { expect(supplemental_claim.full_name).to eq('Jäñe ø Doé') }
    end

    describe 'ssn' do
      it { expect(supplemental_claim.ssn).to eq(auth_headers['X-VA-SSN']) }
    end

    describe 'file_number' do
      it { expect(supplemental_claim.file_number).to eq(auth_headers['X-VA-File-Number']) }
    end

    describe 'veteran_dob_month' do
      it { expect(supplemental_claim.veteran_dob_month).to eq('12') }
    end

    describe 'veteran_dob_day' do
      it { expect(supplemental_claim.veteran_dob_day).to eq('31') }
    end

    describe 'veteran_dob_year' do
      it { expect(supplemental_claim.veteran_dob_year).to eq('1969') }
    end

    describe 'veteran_service_number' do
      it { expect(supplemental_claim.veteran_service_number).to eq(auth_headers['X-VA-Service-Number']) }
    end

    describe 'consumer_name' do
      it { expect(supplemental_claim.consumer_name).to eq(auth_headers['X-Consumer-Username']) }
    end

    describe 'consumer_id' do
      it { expect(supplemental_claim.consumer_id).to eq(auth_headers['X-Consumer-ID']) }
    end
  end

  context 'extra form data' do
    let(:form_data) { fixture_as_json 'valid_200995_extra.json', version: 'v2' }
    let(:supplemental_claim) { create(:extra_supplemental_claim) }
    let(:veteran) { form_data['data']['attributes']['veteran'] }

    context 'mailing address' do
      let(:address) { veteran['address'] }

      describe 'mailing_address_number_and_street' do
        it { expect(supplemental_claim.mailing_address_number_and_street).to eq('123 Main St Suite #1200 Box 4') }
      end

      describe 'mailing_address_city' do
        it { expect(supplemental_claim.mailing_address_city).to eq(address['city']) }
      end

      describe 'mailing_address_state' do
        it { expect(supplemental_claim.mailing_address_state).to eq(address['stateCode']) }
      end

      describe 'mailing_address_country' do
        it { expect(supplemental_claim.mailing_address_country).to eq(address['countryCodeISO2']) }
      end

      describe 'zip_code_5' do
        it { expect(supplemental_claim.zip_code_5).to eq(address['zipCode5']) }
      end

      describe 'veteran_phone_data' do
        it { expect(supplemental_claim.veteran_phone_data).to eq(veteran['phone']) }
      end

      describe 'phone' do
        it { expect(supplemental_claim.phone).to eq '+03-555-800-1111' }
      end
    end
  end

  describe '#stamp_text' do
    let(:supplemental_claim) { build(:supplemental_claim) }

    it { expect(supplemental_claim.stamp_text).to eq('Doé - 6789') }

    it 'truncates the last name if too long' do
      full_last_name = 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdddddddddd'
      supplemental_claim.auth_headers['X-VA-Last-Name'] = full_last_name
      expect(supplemental_claim.stamp_text).to eq 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdd... - 6789'
    end
  end

  describe '#update_status!' do
    let(:supplemental_claim) { create(:supplemental_claim) }

    it 'error status' do
      supplemental_claim.update_status!(status: 'error', code: 'code', detail: 'detail')

      expect(supplemental_claim.status).to eq('error')
      expect(supplemental_claim.code).to eq('code')
      expect(supplemental_claim.detail).to eq('detail')
    end

    it 'other valid status' do
      supplemental_claim.update_status!(status: 'success')

      expect(supplemental_claim.status).to eq('success')
    end

    # TODO: should be implemented with status checking
    it 'invalid status' do
      expect do
        supplemental_claim.update_status!(status: 'invalid_status')
      end.to raise_error(ActiveRecord::RecordInvalid,
                         'Validation failed: Status is not included in the list')
    end

    it 'emits an event' do
      handler = instance_double(AppealsApi::Events::Handler)
      allow(AppealsApi::Events::Handler).to receive(:new).and_return(handler)
      allow(handler).to receive(:handle!)

      supplemental_claim.update_status!(status: 'pending')

      expect(handler).to have_received(:handle!).exactly(1).times
    end

    it 'sends an email' do
      handler = instance_double(AppealsApi::Events::Handler)
      allow(AppealsApi::Events::Handler).to receive(:new).and_return(handler)
      allow(handler).to receive(:handle!)

      supplemental_claim.update_status!(status: 'submitted')

      expect(handler).to have_received(:handle!).exactly(2).times
    end
  end
end
