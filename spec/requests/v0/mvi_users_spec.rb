# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe 'V0::MVIUsers', type: :request do
  describe 'POST #submit' do
    let(:user) { build(:user_with_no_ids) }

    before do
      sign_in_as(user)
    end

    # sad path, wrong form id
    it 'with invalid form id parameter, return 403' do
      invalid_form_id = '21-686C'
      post "/v0/mvi_users/#{invalid_form_id}"
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq("Action is prohibited with id parameter #{invalid_form_id}")
    end

    context('with valid form id parameter') do
      valid_form_id = '21-526EZ'

      # sad path, missing birls only which means we have big problems
      context('when user is missing birls_id only') do
        let(:user) { build(:user, :loa3, birls_id: nil) }

        before do
          sign_in_as(user)
        end

        it 'return 422' do
          post "/v0/mvi_users/#{valid_form_id}"
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('No birls_id while participant_id present')
        end
      end

      # sad path, user has proper ids, can not proxy add
      context('when user has partipant_id and birls_id') do
        let(:user) { build(:user, :loa3) }

        before do
          sign_in_as(user)
        end

        it 'return 403' do
          post "/v0/mvi_users/#{valid_form_id}"
          expect(response).to have_http_status(:forbidden)
        end
      end

      # happy path, make proxy add
      context('when user is missing birls_id and participant_id') do
        let(:user) { build(:user_with_no_ids) }

        before do
          sign_in_as(user)
        end

        it 'return 200, add user to MPI' do
          VCR.use_cassette('mpi/add_person/add_person_success') do
            VCR.use_cassette('mpi/find_candidate/orch_search_with_attributes') do
              VCR.use_cassette('mpi/find_candidate/find_profile_with_identifier') do
                # expect success to be achieved by calling MPI's add_person_proxy
                expect_any_instance_of(MPIData).to receive(:add_person_proxy).once.and_call_original
                post "/v0/mvi_users/#{valid_form_id}"
                expect(response).to have_http_status(:ok)
              end
            end
          end
        end
      end
    end
  end
end
