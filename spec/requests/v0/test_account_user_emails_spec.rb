# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::TestAccountUserEmails', type: :request do
  describe 'POST #create' do
    subject { post '/v0/test_account_user_email', params: }

    let(:email) { 'some-email' }
    let(:email_redis_key) { 'some-email-redis-key' }
    let(:params) { { email: } }
    let(:rendered_error) { { 'errors' => 'invalid params' } }

    before do
      allow(SecureRandom).to receive(:uuid).and_return(email_redis_key)
      allow(Rails.logger).to receive(:info)
    end

    shared_context 'bad_request' do
      it 'responds with bad request status' do
        subject

        assert_response :bad_request
      end

      it 'responds with error' do
        subject

        expect(JSON.parse(response.body)).to eq(rendered_error)
      end
    end

    context 'when params does not include email' do
      let(:params) { { some_params: 'some-params' } }

      it_behaves_like 'bad_request'
    end

    context 'when params include email' do
      let(:params) { { email: } }

      context 'and email param is empty' do
        let(:email) { '' }

        it_behaves_like 'bad_request'
      end

      context 'and email param is not empty' do
        let(:email) { 'some-email' }
        let(:expected_log_message) { "[V0][TestAccountUserEmailsController] create, key:#{email_redis_key}" }

        it 'responds with created status' do
          subject

          assert_response :created
        end

        it 'responds with test_account_user_email_uuid' do
          subject

          expect(JSON.parse(response.body)['test_account_user_email_uuid']).to eq(email_redis_key)
        end

        it 'makes a create log to rails logger' do
          subject

          expect(Rails.logger).to have_received(:info).with(expected_log_message)
        end
      end
    end
  end
end
