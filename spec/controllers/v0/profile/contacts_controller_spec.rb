# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::ContactsController, type: :controller do
  include SchemaMatchers

  let(:idme_uuid) { 'dd681e7d6dea41ad8b80f8d39284ef29' }
  let(:user) { build(:user, :loa3, idme_uuid:) }
  let(:loa1_user) { build(:user, :loa1) }
  let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_200' }

  describe 'GET /v0/profile/contacts' do
    subject { get :index }

    around do |ex|
      VCR.use_cassette(cassette) { ex.run }
    end

    context 'successful request' do
      it 'returns emergency contacts' do
        sign_in_as user
        expect(subject).to have_http_status(:success)
        expect(response).to match_response_schema('contacts')
      end

      it 'logs start and finish events and emits success metrics' do
        sign_in_as user
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:measure)
        allow(StatsD).to receive(:increment)

        subject

        expect(Rails.logger).to have_received(:info).with(hash_including(event: 'profile.contacts.request.start'))
        expect(Rails.logger).to have_received(:info).with(
          hash_including(event: 'profile.contacts.request.finish', contact_count: 4, upstream_status: 200)
        )
        expect(StatsD).to have_received(:measure).with('profile.contacts.latency', kind_of(Numeric))
        expect(StatsD).to have_received(:increment).with('profile.contacts.success')
      end
    end

    context 'user is not authenticated' do
      it 'returns an unauthorized status code' do
        expect(subject).to have_http_status(:unauthorized)
      end
    end

    context 'user is loa1' do
      it 'returns a forbidden status code' do
        sign_in_as loa1_user
        expect(subject).to have_http_status(:forbidden)
      end
    end

    context '500 Internal Server Error from VA Profile Service' do
      let(:idme_uuid) { '88f572d4-91af-46ef-a393-cba6c351e252' }
      let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_500' }

      it 'returns a bad request status code' do
        sign_in_as user
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:info)
        allow(StatsD).to receive(:increment)
        allow(StatsD).to receive(:measure)
        expect(subject).to have_http_status(:bad_request)
        expect(Rails.logger).to have_received(:error).with(hash_including(event: 'profile.contacts.backend_error'))
        expect(StatsD).to have_received(:increment).with('profile.contacts.error')
      end
    end

    context '504 Gateway Timeout from VA Profile Service' do
      let(:idme_uuid) { '88f572d4-91af-46ef-a393-cba6c351e252' }
      let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_500' }

      it 'returns a gateway timeout status code' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:info)
        allow(StatsD).to receive(:increment)
        allow(StatsD).to receive(:measure)
        sign_in_as user
        expect(subject).to have_http_status(:gateway_timeout)
        expect(Rails.logger).to have_received(:error).with(hash_including(event: 'profile.contacts.unhandled_error'))
        expect(StatsD).to have_received(:increment).with('profile.contacts.error')
      end
    end

    context 'empty contacts response' do
      let(:idme_uuid) { 'dd681e7d6dea41ad8b80f8d39284ef29' }
      let(:cassette) { 'va_profile/profile/v3/health_benefit_bio_200' }

      it 'logs empty metrics when contacts array is empty' do
        # Stub service to return empty contacts while status 200
        sign_in_as user
        allow_any_instance_of(VAProfile::Profile::V3::Service)
          .to receive(:get_health_benefit_bio).and_wrap_original do |orig|
          response = orig.call
          allow(response).to receive(:contacts).and_return([])
          response
        end
        allow(Rails.logger).to receive(:info)
        allow(StatsD).to receive(:increment)
        allow(StatsD).to receive(:measure)

        subject

        expect(Rails.logger).to have_received(:info).with(
          hash_including(event: 'profile.contacts.request.finish', contact_count: 0, upstream_status: 200)
        )
        expect(StatsD).to have_received(:increment).with('profile.contacts.empty')
      end
    end
  end
end
