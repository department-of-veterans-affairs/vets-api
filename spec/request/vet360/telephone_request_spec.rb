# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'telephone', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Timecop.freeze(Time.local(2018, 6, 6, 15, 35, 55))
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  after do
    Timecop.return
  end

  describe 'POST /v0/profile/telephones' do
    let(:telephone) { build(:telephone, vet360_id: user.vet360_id) }

    context 'with a 200 response' do
      it 'should match the telephone schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/post_telephone_success') do
          post(
            '/v0/profile/telephones',
            telephone.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end

      it 'creates a new AsyncTransaction::Vet360::TelephoneTransaction db record' do
        VCR.use_cassette('vet360/contact_information/post_telephone_success') do
          expect do
            post(
              '/v0/profile/telephones',
              telephone.to_json,
              auth_header.update(
                'Content-Type' => 'application/json', 'Accept' => 'application/json'
              )
            )
          end.to change(AsyncTransaction::Vet360::TelephoneTransaction, :count).from(0).to(1)
        end
      end
    end

    context 'with a 400 response' do
      it 'should match the errors schema', :aggregate_failures do
        telephone.id = 42

        VCR.use_cassette('vet360/contact_information/post_telephone_w_id_error') do
          post(
            '/v0/profile/telephones',
            telephone.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a 403 response' do
      it 'should return a forbidden response' do
        VCR.use_cassette('vet360/contact_information/post_telephone_status_403') do
          post(
            '/v0/profile/telephones',
            telephone.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'with a validation issue' do
      it 'should match the errors schema', :aggregate_failures do
        telephone.phone_number = ''

        post(
          '/v0/profile/telephones',
          telephone.to_json,
          auth_header.update(
            'Content-Type' => 'application/json', 'Accept' => 'application/json'
          )
        )

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "phone-number - can't be blank"
      end
    end
  end

  describe 'PUT /v0/profile/telephones' do
    let(:telephone) { build(:telephone, vet360_id: user.vet360_id) }

    before { telephone.id = 42 }

    context 'with a 200 response' do
      it 'should match the telephone schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/put_telephone_success') do
          put(
            '/v0/profile/telephones',
            telephone.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end

      it 'creates a new AsyncTransaction::Vet360::TelephoneTransaction db record' do
        VCR.use_cassette('vet360/contact_information/put_telephone_success') do
          expect do
            put(
              '/v0/profile/telephones',
              telephone.to_json,
              auth_header.update(
                'Content-Type' => 'application/json', 'Accept' => 'application/json'
              )
            )
          end.to change(AsyncTransaction::Vet360::TelephoneTransaction, :count).from(0).to(1)
        end
      end
    end

    context 'with a validation issue' do
      it 'should match the errors schema', :aggregate_failures do
        telephone.phone_number = ''

        put(
          '/v0/profile/telephones',
          telephone.to_json,
          auth_header.update(
            'Content-Type' => 'application/json', 'Accept' => 'application/json'
          )
        )

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(errors_for(response)).to include "phone-number - can't be blank"
      end
    end





    context 'when effective_end_date is included' do

      let(:telephone) { 
        build(:telephone,
          vet360_id: user.vet360_id, 
          effective_end_date: Time.now.utc.iso8601,
          phone_number: '5551234'
        ) 
      }

      before do
        allow_any_instance_of(User).to receive(:icn).and_return('1234')
        telephone.id = 1299
      end


      it 'effective_end_date is ignored', {:aggregate_failures => true} do
        VCR.use_cassette('vet360/contact_information/put_telephone_ignore_eed', VCR::MATCH_EVERYTHING) do

          put(
            '/v0/profile/telephones',
            telephone.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end
    end





  end

  describe 'DELETE /v0/profile/telephones' do
    let(:telephone) { 
      build(:telephone, vet360_id: user.vet360_id) 
    }

    before do
      allow_any_instance_of(User).to receive(:icn).and_return('64762895576664260')
      telephone.id = 42
    end

    context 'with a 200 response' do
      it 'should match the telephone schema', :aggregate_failures do
        VCR.use_cassette('vet360/contact_information/delete_telephone_success', VCR::MATCH_EVERYTHING) do

          delete(
            '/v0/profile/telephones',
            telephone.to_json,
            auth_header.update(
              'Content-Type' => 'application/json', 'Accept' => 'application/json'
            )
          )

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vet360/transaction_response')
        end
      end
    end
  end
end

# delete('/v0/profile/telephones', telephone.to_json, auth_header.update( 'Content-Type' => 'application/json', 'Accept' => 'application/json' ))