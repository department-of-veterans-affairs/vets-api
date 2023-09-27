# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/health_benefit/service'
require 'va_profile/health_benefit/configuration'
require 'va_profile/health_benefit/associated_person_response'
require 'va_profile/models/associated_person'

describe VAProfile::HealthBenefit::Service do
  let(:user) { build(:user, :loa3) }
  let(:idme_uuid) { SecureRandom.uuid }
  let(:service) { described_class.new(user) }
  let(:fixture_path) { %w[spec fixtures va_profile health_benefit_v1_read_ap.json] }
  let(:response_body) { Rails.root.join(*fixture_path).read }

  before do
    allow(user).to receive(:idme_uuid).and_return(idme_uuid)
  end

  around do |example|
    # using webmock & json fixtures instead of VCR until VA Profile API access is granted
    VCR.turned_off { example.run }
  end

  describe '#get_emergency_contacts' do
    let(:resource) { service.send(:v1_read_path) }

    context 'when request is successful' do
      it "returns an AssociatedPersonsResponse with status 'ok'" do
        stub_request(:get, resource).to_return(body: response_body)
        result = service.get_emergency_contacts
        expect(result.ok?).to be(true)
        expect(result).to be_a(VAProfile::HealthBenefit::AssociatedPersonsResponse)
        expect(result.associated_persons.size).to eq(2)
      end
    end

    context 'when resource is not found' do
      it 'raises a BackendServiceException' do
        stub_request(:get, resource).to_return(status: 404)
        expect { service.get_emergency_contacts }.to raise_error Common::Exceptions::BackendServiceException
      end
    end

    context 'when the server experiences an error' do
      it 'raises a BackendServiceException' do
        stub_request(:get, resource).to_return(status: 500)
        expect { service.get_emergency_contacts }.to raise_error Common::Exceptions::BackendServiceException
      end
    end
  end

  describe '#get_next_of_kin' do
    let(:resource) { service.send(:v1_read_path) }

    context 'when request is successful' do
      it "returns an AssociatedPersonsResponse with status 'ok'" do
        stub_request(:get, resource).to_return(body: response_body)
        result = service.get_next_of_kin
        expect(result.ok?).to be(true)
        expect(result).to be_a(VAProfile::HealthBenefit::AssociatedPersonsResponse)
        expect(result.associated_persons.size).to eq(3)
      end
    end

    context 'when resource is not found' do
      it "returns an AssociatedPersonsResponse with not-'ok' status" do
        stub_request(:get, resource).to_return(status: 404)
        expect { service.get_next_of_kin }.to raise_error Common::Exceptions::BackendServiceException
      end
    end

    context 'when the server experiences an error' do
      it "returns an AssociatedPersonsResponse with not-'ok' status" do
        stub_request(:get, resource).to_return(status: 500)
        expect { service.get_next_of_kin }.to raise_error Common::Exceptions::BackendServiceException
      end
    end
  end
end
