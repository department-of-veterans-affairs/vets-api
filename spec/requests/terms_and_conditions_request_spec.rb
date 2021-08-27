# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'terms_and_conditions' do
  include SchemaMatchers

  let(:current_user) { create(:user) }
  let!(:terms1) { create(:terms_and_conditions, latest: true, name: 'one') }
  let!(:terms2) { create(:terms_and_conditions, latest: false, name: 'two') }
  let!(:terms21) { create(:terms_and_conditions, name: terms2.name, latest: true) }
  let!(:terms3) { create(:terms_and_conditions, latest: true, name: 'three') }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  it 'responds to GET #index' do
    get '/v0/terms_and_conditions'

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('terms_and_conditions')
  end

  it 'responds to GET #index when camel-inflected' do
    get '/v0/terms_and_conditions', headers: inflection_header

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_camelized_response_schema('terms_and_conditions')
  end

  it 'responds to GET #latest' do
    get "/v0/terms_and_conditions/#{terms2.name}/versions/latest"

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('terms_and_conditions_single')

    json = JSON.parse(response.body)
    expect(json['data']['id']).to eq(terms21.id.to_s)
  end

  it 'responds to GET #latest when camel-inflected' do
    get "/v0/terms_and_conditions/#{terms2.name}/versions/latest", headers: inflection_header

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_camelized_response_schema('terms_and_conditions_single')

    json = JSON.parse(response.body)
    expect(json['data']['id']).to eq(terms21.id.to_s)
  end

  context 'with some acceptances' do
    before do
      sign_in_as(current_user)
    end

    let!(:terms2_acceptance) do
      create(:terms_and_conditions_acceptance, user_uuid: current_user.uuid, terms_and_conditions: terms2)
    end
    let!(:terms21_acceptance) do
      create(:terms_and_conditions_acceptance, user_uuid: current_user.uuid, terms_and_conditions: terms21)
    end

    describe 'getting user data' do
      it 'responds to GET #user_data' do
        get "/v0/terms_and_conditions/#{terms2.name}/versions/latest/user_data"

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('terms_and_conditions_acceptance')
      end

      it 'responds to GET #user_data when camel-inflected' do
        get "/v0/terms_and_conditions/#{terms2.name}/versions/latest/user_data", headers: inflection_header

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('terms_and_conditions_acceptance')
      end

      it 'gives me information about whether the user accepted the latest' do
        get "/v0/terms_and_conditions/#{terms2.name}/versions/latest/user_data"
        json = JSON.parse(response.body)
        expect(Time.zone.parse(json['data']['attributes']['created_at']).to_i).to eq(terms21_acceptance.created_at.to_i)
      end
    end

    describe 'accepting the latest' do
      it 'complains if I try to accept it again' do
        post "/v0/terms_and_conditions/#{terms2.name}/versions/latest/user_data"

        expect(response.status).to eq(422)
        expect(response.body).to be_a(String)
        json = JSON.parse(response.body)
        expect(json['errors'][0]['title']).to eq('User uuid has already been taken')
      end
    end
  end

  context 'with no acceptances' do
    before do
      sign_in_as(current_user)
    end

    describe 'getting user data' do
      it 'responds to GET #user_data with a 404' do
        get "/v0/terms_and_conditions/#{terms2.name}/versions/latest/user_data"

        expect(response.status).to eq(404)
        expect(response.body).to be_a(String)
        json = JSON.parse(response.body)
        expect(json['errors'][0]['title']).to eq('Record not found')
      end

      describe 'accepting the latest' do
        let!(:start_time) { Time.zone.now }

        it 'lets me accept it' do
          post "/v0/terms_and_conditions/#{terms2.name}/versions/latest/user_data"

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('terms_and_conditions_acceptance')
        end

        it 'lets me accept it when camel-inflected' do
          post "/v0/terms_and_conditions/#{terms2.name}/versions/latest/user_data", headers: inflection_header

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_camelized_response_schema('terms_and_conditions_acceptance')
        end

        it 'creates the acceptance' do
          post "/v0/terms_and_conditions/#{terms2.name}/versions/latest/user_data"
          expect(TermsAndConditionsAcceptance.for_user(current_user).for_terms(terms2.name).for_latest).to be_present
        end

        it 'returns the acceptance' do
          Timecop.freeze(start_time)
          post "/v0/terms_and_conditions/#{terms2.name}/versions/latest/user_data"
          json = JSON.parse(response.body)
          expect(Time.zone.parse(json['data']['attributes']['created_at']).to_i).to eq(start_time.to_i)
          Timecop.return
        end
      end
    end
  end
end
