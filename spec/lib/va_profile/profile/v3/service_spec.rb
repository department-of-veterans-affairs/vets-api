# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/profile/v3/service'

describe VAProfile::Profile::V3::Service do
  include SchemaMatchers

  subject { described_class.new(user) }

  describe '#get_military_info' do
    let(:user) { build(:user, :loa3, edipi: '1100377582') }

    context 'when successful' do
      it 'returns a valid schema' do
        VCR.use_cassette('va_profile/profile/v3/military_info_200') do
          response = subject.get_military_info

          expect(response.status).to eq(200)
          expect(response).to match_response_schema('va_profile/profile/v3/military_info_response')
        end
      end
    end
  end

  describe '#get_health_benefit_bio' do
    let(:user) { build(:user, :loa3, idme_uuid:) }

    context '200 response' do
      let(:idme_uuid) { 'dd681e7d6dea41ad8b80f8d39284ef29' }

      it 'returns the contacts (aka associated_persons) for a user' do
        VCR.use_cassette('va_profile/profile/v3/health_benefit_bio_200') do
          response = subject.get_health_benefit_bio
          expect(response.status).to eq(200)
          expect(response.contacts.size).to eq(4)
        end
      end
    end

    context '404 response' do
      let(:idme_uuid) { '88f572d4-91af-46ef-a393-cba6c351e252' }

      it 'includes messages recieved from the api' do
        VCR.use_cassette('va_profile/profile/v3/health_benefit_bio_404') do
          response = subject.get_health_benefit_bio
          expect(response.status).to eq(404)
          expect(response.associated_persons.size).to eq(0)
          expect(response.messages.size).to eq(1)
        end
      end
    end
  end
end
