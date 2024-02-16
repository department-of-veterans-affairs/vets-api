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

    context '200 response' do
      let(:idme_uuid) { 'dd681e7d6dea41ad8b80f8d39284ef29' }

      it 'returns the contacts (aka associated_persons) for a user, sorted' do
        VCR.use_cassette('va_profile/profile/v3/health_benefit_bio_200') do
          response = subject.get_health_benefit_bio
          expect(response.status).to eq(200)
          expect(response.contacts.size).to eq(4)
          types = response.contacts.map(&:contact_type)
          expect(types).to match_array(VAProfile::Models::AssociatedPerson::CONTACT_TYPES)
        end
      end
    end

    context '404 response' do
      let(:idme_uuid) { '88f572d4-91af-46ef-a393-cba6c351e252' }

      it 'includes messages recieved from the api' do
        VCR.use_cassette('va_profile/profile/v3/health_benefit_bio_404') do
          response = subject.get_health_benefit_bio
          expect(response.status).to eq(404)
          expect(response.contacts.size).to eq(0)
          expect(response.messages.size).to eq(1)
        end
      end
    end
  end

  describe '#get_gender_identity_traits' do
    let(:user) { build(:user, :loa3, edipi:) }

    context '200 response' do
      let(:edipi) { '1005123832' }

      it 'returns gender identity traits for a user' do
        VCR.use_cassette('va_profile/profile/v3/gender_identity_traits_bio_200.yml') do
          response = subject.get_gender_identity_traits
          expect(response).to eq(200)
          expect(response.gender_identity_traits).not_to be_nil
        end
      end
    end
  end
end
