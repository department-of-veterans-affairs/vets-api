# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::EmailAddressesController, type: :controller do
  let(:user) { build(:user, :loa3) }
  let(:loa1_user) { build(:user, :loa1) }
  let(:email_params) do
    {
      email_address: 'test@example.com',
      confirmation_date: '2023-01-01T00:00:00.000Z'
    }
  end
  let(:email_params_with_id) do
    {
      email_address: 'test@example.com',
      confirmation_date: '2023-01-01T00:00:00.000Z',
      id: 123,
      transaction_id: 'b2fab2b5-6af0-45e1-a9e2-394347af9123'
    }
  end

  before do
    allow(Rails.logger).to receive(:info)
    allow(VAProfileRedis::V2::Cache).to receive(:invalidate)
  end

  describe 'authentication and authorization' do
    context 'when user is not authenticated' do
      it 'returns unauthorized for create' do
        post :create, params: email_params
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for create_or_update' do
        patch :create_or_update, params: email_params
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for update' do
        put :update, params: email_params_with_id
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for destroy' do
        delete :destroy, params: email_params_with_id
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'with authenticated LOA3 user' do
    before do
      sign_in_as(user)
      allow_any_instance_of(User).to receive(:icn).and_return('1012666073V986297')
    end

    describe '#create' do
      context 'with valid parameters' do
        it 'creates an email address and returns transaction' do
          VCR.use_cassette('va_profile/v2/contact_information/post_email_success') do
            post :create, params: email_params

            expect(response).to have_http_status(:ok)
          end
        end

        it 'logs the request completion' do
          VCR.use_cassette('va_profile/v2/contact_information/post_email_success') do
            post :create, params: email_params

            expect(Rails.logger).to have_received(:info).with(
              'EmailAddressesController#create request completed',
              hash_including(:user_uuid, :sso_cookie_contents)
            )
          end
        end

        it 'invalidates the cache' do
          VCR.use_cassette('va_profile/v2/contact_information/post_email_success') do
            post :create, params: email_params

            expect(VAProfileRedis::V2::Cache).to have_received(:invalidate)
          end
        end
      end

      context 'with invalid parameters' do
        let(:invalid_params) { { email_address: 'invalid-email' } }

        it 'returns validation errors' do
          post :create, params: invalid_params

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)).to include('errors')
        end
      end

      context 'when VA Profile service returns an error' do
        it 'handles service errors' do
          VCR.use_cassette('va_profile/v2/contact_information/post_email_status_400') do
            post :create, params: email_params

            expect(response).to have_http_status(:bad_request)
          end
        end
      end

      context 'when VA Profile service times out' do
        it 'handles timeout errors' do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)

          post :create, params: email_params

          expect(response).to have_http_status(:gateway_timeout)
        end
      end
    end

    describe '#create_or_update' do
      context 'with valid parameters' do
        it 'creates or updates an email address and returns transaction' do
          VCR.use_cassette('va_profile/v2/contact_information/put_email_success') do
            post :create_or_update, params: email_params

            expect(response).to have_http_status(:ok)
          end
        end

        it 'does not log request completion' do
          VCR.use_cassette('va_profile/v2/contact_information/put_email_success') do
            post :create_or_update, params: email_params

            expect(Rails.logger).not_to have_received(:info).with(
              /EmailAddressesController#create_or_update request completed/
            )
          end
        end

        it 'invalidates the cache' do
          VCR.use_cassette('va_profile/v2/contact_information/put_email_success') do
            post :create_or_update, params: email_params

            expect(VAProfileRedis::V2::Cache).to have_received(:invalidate)
          end
        end
      end

      context 'with invalid parameters' do
        let(:invalid_params) { { email_address: 'invalid-email' } }

        it 'returns validation errors' do
          post :create_or_update, params: invalid_params

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)).to include('errors')
        end
      end
    end

    describe '#update' do
      context 'with valid parameters' do
        it 'updates an email address and returns transaction' do
          VCR.use_cassette('va_profile/v2/contact_information/put_email_success') do
            put :update, params: email_params_with_id

            expect(response).to have_http_status(:ok)
          end
        end

        it 'logs the request completion' do
          VCR.use_cassette('va_profile/v2/contact_information/put_email_success') do
            put :update, params: email_params_with_id

            expect(Rails.logger).to have_received(:info).with(
              'EmailAddressesController#update request completed',
              hash_including(:user_uuid, :sso_cookie_contents)
            )
          end
        end

        it 'invalidates the cache' do
          VCR.use_cassette('va_profile/v2/contact_information/put_email_success') do
            put :update, params: email_params_with_id

            expect(VAProfileRedis::V2::Cache).to have_received(:invalidate)
          end
        end
      end

      context 'with invalid parameters' do
        let(:invalid_params) { { id: 123, email_address: 'invalid-email' } }

        it 'returns validation errors' do
          put :update, params: invalid_params

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)).to include('errors')
        end
      end
    end

    describe '#destroy' do
      context 'with valid parameters' do
        it 'deletes an email address and returns transaction' do
          VCR.use_cassette('va_profile/v2/contact_information/delete_email_success') do
            delete :destroy, params: email_params_with_id

            expect(response).to have_http_status(:ok)
          end
        end

        it 'logs the request completion' do
          VCR.use_cassette('va_profile/v2/contact_information/delete_email_success') do
            delete :destroy, params: email_params_with_id

            expect(Rails.logger).to have_received(:info).with(
              'EmailAddressesController#destroy request completed',
              hash_including(:user_uuid, :sso_cookie_contents)
            )
          end
        end

        it 'invalidates the cache' do
          VCR.use_cassette('va_profile/v2/contact_information/delete_email_success') do
            delete :destroy, params: email_params_with_id

            expect(VAProfileRedis::V2::Cache).to have_received(:invalidate)
          end
        end

        it 'adds effective_end_date to parameters' do
          allow(Time).to receive(:now).and_return(Time.parse('2023-01-01T12:00:00Z'))
          expected_time = '2023-01-01T12:00:00Z'

          expect_any_instance_of(V0::Profile::EmailAddressesController)
            .to receive(:write_to_vet360_and_render_transaction!)
            .with(
              'email',
              hash_including(effective_end_date: expected_time),
              http_verb: 'put'
            )

          VCR.use_cassette('va_profile/v2/contact_information/delete_email_success') do
            delete :destroy, params: email_params_with_id
          end
        end
      end
    end

    describe 'parameter handling' do
      let(:all_params) do
        {
          email_address: 'test@example.com',
          confirmation_date: '2023-01-01T00:00:00.000Z',
          id: 123,
          transaction_id: 'b2fab2b5-6af0-45e1-a9e2-394347af9123',
          unauthorized_param: 'should_be_filtered'
        }
      end

      it 'permits only allowed parameters' do
        expect_any_instance_of(V0::Profile::EmailAddressesController)
          .to receive(:write_to_vet360_and_render_transaction!)
          .with(
            'email',
            hash_excluding(:unauthorized_param)
          )

        VCR.use_cassette('va_profile/v2/contact_information/post_email_success') do
          post :create, params: all_params
        end
      end

      it 'includes all permitted parameters' do
        expect_any_instance_of(V0::Profile::EmailAddressesController)
          .to receive(:write_to_vet360_and_render_transaction!)
          .with(
            'email',
            hash_including(
              :email_address,
              :confirmation_date,
              :id,
              :transaction_id
            )
          )

        VCR.use_cassette('va_profile/v2/contact_information/post_email_success') do
          post :create, params: all_params
        end
      end
    end

    describe 'HTTP verb handling' do
      it 'uses POST for create action' do
        expect_any_instance_of(V0::Profile::EmailAddressesController)
          .to receive(:write_to_vet360_and_render_transaction!)
          .with('email', anything)

        VCR.use_cassette('va_profile/v2/contact_information/post_email_success') do
          post :create, params: email_params
        end
      end

      it 'uses synthetic UPDATE verb for create_or_update action' do
        expect_any_instance_of(V0::Profile::EmailAddressesController)
          .to receive(:write_to_vet360_and_render_transaction!)
          .with('email', anything, http_verb: 'update')

        VCR.use_cassette('va_profile/v2/contact_information/put_email_success') do
          put :create_or_update, params: email_params
        end
      end

      it 'uses PUT for update action' do
        expect_any_instance_of(V0::Profile::EmailAddressesController)
          .to receive(:write_to_vet360_and_render_transaction!)
          .with('email', anything, http_verb: 'put')

        VCR.use_cassette('va_profile/v2/contact_information/put_email_success') do
          put :update, params: email_params_with_id
        end
      end

      it 'uses PUT for destroy action' do
        expect_any_instance_of(V0::Profile::EmailAddressesController)
          .to receive(:write_to_vet360_and_render_transaction!)
          .with('email', anything, http_verb: 'put')

        VCR.use_cassette('va_profile/v2/contact_information/delete_email_success') do
          delete :destroy, params: email_params_with_id
        end
      end
    end
  end
end
