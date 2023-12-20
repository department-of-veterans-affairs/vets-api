# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/health_benefit/service'
require 'va_profile/health_benefit/configuration'
require 'va_profile/health_benefit/associated_persons_response'
require 'va_profile/models/associated_person'

describe VAProfile::HealthBenefit::Service do
  let(:user) { build(:user, :loa3) }
  let(:idme_uuid) { SecureRandom.uuid }
  let(:service) { described_class.new(user) }
  let(:fixture_path) { %w[spec fixtures va_profile health_benefit_v1_associated_persons.json] }
  let(:response_body) { Rails.root.join(*fixture_path).read }

  before do
    allow(user).to receive(:idme_uuid).and_return(idme_uuid)
  end

  describe '#get_associated_persons' do
    around do |example|
      # using webmock & json fixtures instead of VCR until VA Profile API access is granted
      VCR.turned_off do
        # disable data mocking for the VA Profile Health Benefit API
        with_settings(Settings.vet360.health_benefit, mock: false) do
          example.run
        end
      end
    end

    let(:resource) { service.send(:v1_read_path) }

    context 'when request is successful' do
      it "returns an AssociatedPersonsResponse with status 'ok'" do
        stub_request(:get, resource).to_return(body: response_body)
        result = service.get_associated_persons
        expect(result.ok?).to be(true)
        expect(result).to be_a(VAProfile::HealthBenefit::AssociatedPersonsResponse)
        expect(result.associated_persons.size).to eq(2)
      end
    end

    context 'when resource is not found' do
      it 'raises a BackendServiceException' do
        stub_request(:get, resource).to_return(status: 404)
        expect { service.get_associated_persons }.to raise_error Common::Exceptions::BackendServiceException
      end
    end

    context 'when the service experiences an error' do
      it 'raises a BackendServiceException' do
        stub_request(:get, resource).to_return(status: 500)
        expect { service.get_associated_persons }.to raise_error Common::Exceptions::BackendServiceException
      end
    end
  end

  describe '#get_relationship_types' do
    it 'returns a RelationshipTypesResponse with status "ok"' do
      VCR.use_cassette('va_profile/health_benefit/relationship_types', record: :once) do
        result = service.get_relationship_types
        expect(result).to be_a(VAProfile::HealhtBenefit::RelationshipTypesResponse)
        expect(result.relationship_types.size).to be > 0
      end
    end
  end
end
