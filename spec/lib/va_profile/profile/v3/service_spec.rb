# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/profile/v3/service'
require 'va_profile/models/associated_person'

describe VAProfile::Profile::V3::Service do
  include SchemaMatchers

  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3, edipi: '1100377582') }

  describe '#get_military_info' do
    it 'returns multiple military bios' do
      VCR.use_cassette('va_profile/profile/v3/military_info_200') do
        response = subject.get_military_info

        expect(response.status).to eq(200)

        military_person = response.body['profile']['military_person']
        expect(military_person['military_summary']).not_to be_nil
        expect(military_person['military_occupations']).not_to be_nil
        expect(military_person['military_service_history']).not_to be_nil
        expect(military_person['unit_assignments']).not_to be_nil
      end
    end
  end

  describe '#get_military_occupations' do
    context 'valid edipi' do
      it 'returns military occupations' do
        VCR.use_cassette('va_profile/profile/v3/military_occupations_200') do
          response = subject.get_military_occupations
          expect(response.status).to eq(200)
          expect(response.military_occupations.size).to eq(3)
        end
      end
    end

    context 'invalid edipi' do
      let(:user) { build(:user, :loa3, edipi: '') }

      it 'returns no data' do
        VCR.use_cassette('va_profile/profile/v3/military_occupations_error') do
          response = subject.get_military_occupations
          expect(response.status).to eq(200)
          expect(response.military_occupations.size).to eq(0)
          expect(response.messages.size).to eq(1)
        end
      end
    end
  end

  describe '#get_health_benefit_bio' do
    let(:user) { build(:user, :loa3, idme_uuid:) }

    let(:cassette_filename) { "spec/support/vcr_cassettes/#{cassette}.yml" }
    let(:cassette_data) { YAML.load_file(cassette_filename) }
    let(:va_profile_tx_audit_id) do
      cassette_data['http_interactions'][0]['response']['headers']['Vaprofiletxauditid'][0]
    end
    let(:code) { 'MVI203' }
    let(:debug_data) do
      {
        code:,
        status:,
        message:,
        va_profile_tx_audit_id:
      }
    end

    around do |ex|
      VCR.use_cassette(cassette) { ex.run }
    end

    context '200 response' do
      let(:idme_uuid) { 'dd681e7d6dea41ad8b80f8d39284ef29' }
      let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_200' }

      it 'returns the contacts (aka associated_persons) for a user, sorted' do
        response = subject.get_health_benefit_bio
        expect(response.status).to eq(200)
        expect(response.contacts.size).to eq(4)
        types = response.contacts.map(&:contact_type)
        valid_contact_types =
          VAProfile::Models::AssociatedPerson::PERSONAL_HEALTH_CARE_CONTACT_TYPES
        expect(types).to match_array(valid_contact_types)
      end

      it 'logs request and response events and success metrics' do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:measure)

        subject.get_health_benefit_bio

        expect(Rails.logger).to have_received(:info).with(
          hash_including(event: 'va_profile.health_benefit_bio.request', bios_requested: 1)
        )
        expect(Rails.logger).to have_received(:info).with(
          hash_including(event: 'va_profile.health_benefit_bio.response', contacts_present: true)
        )
        expect(StatsD).to have_received(:measure).with('va_profile.health_benefit_bio.latency', kind_of(Numeric))
      end
    end

    context '404 response' do
      let(:idme_uuid) { '88f572d4-91af-46ef-a393-cba6c351e252' }
      let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_404' }
      let(:status) { 404 }
      let(:message) do
        'MVI201 MviNotFound The person with the identifier requested was not found in MVI.'
      end
      let(:code) { 'MVI201' }

      it 'includes messages received from the api' do
        response = subject.get_health_benefit_bio
        expect(response.status).to eq(404)
        expect(response.contacts.size).to eq(0)
        expect(response.messages.size).to eq(1)
      end
    end

    context '500 response' do
      let(:idme_uuid) { '88f572d4-91af-46ef-a393-cba6c351e252' }
      let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_500' }

      it 'raises an error' do
        expect { subject.get_health_benefit_bio }.to raise_error(Common::Exceptions::BackendServiceException)
      end

      it 'logs server_error and increments error metric' do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)
        expect { subject.get_health_benefit_bio }
          .to raise_error(Common::Exceptions::BackendServiceException)
        expect(Rails.logger).to have_received(:error).with(
          hash_including(event: 'va_profile.health_benefit_bio.server_error')
        )
      end
    end

    context 'api timeout' do
      let(:idme_uuid) { '88f572d4-91af-46ef-a393-cba6c351e252' }
      let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_500' }

      it 'raises an error' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        expect { subject.get_health_benefit_bio }.to raise_error(Common::Exceptions::GatewayTimeout)
      end

      it 'increments error metric on timeout' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        allow(StatsD).to receive(:increment)
        expect { subject.get_health_benefit_bio }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end

    context 'empty contacts success' do
      let(:idme_uuid) { 'dd681e7d6dea41ad8b80f8d39284ef29' }
      let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_200' }

      it 'increments empty metric when contacts are blank' do
        allow(StatsD).to receive(:increment)
        allow(StatsD).to receive(:measure)
        allow(Rails.logger).to receive(:info)
        # Wrap original to override contacts
        allow(VAProfile::Profile::V3::HealthBenefitBioResponse)
          .to receive(:new).and_wrap_original do |orig, resp|
          response = orig.call(resp)
          allow(response).to receive(:contacts).and_return([])
          response
        end
        subject.get_health_benefit_bio
        expect(Rails.logger).to have_received(:info).with(
          hash_including(event: 'va_profile.health_benefit_bio.response', contacts_present: false)
        )
      end
    end
  end
end
