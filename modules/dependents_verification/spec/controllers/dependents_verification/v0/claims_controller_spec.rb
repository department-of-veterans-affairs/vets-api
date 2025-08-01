# frozen_string_literal: true

require 'rails_helper'
require 'dependents_verification/monitor'
require 'dependents_verification/benefits_intake/submit_claim_job'
require 'support/controller_spec_helper'

RSpec.describe DependentsVerification::V0::ClaimsController, type: :request do
  let(:monitor) { double('DependentsVerification::Monitor') }
  let(:user) { create(:evss_user, participant_id: '600049703', ssn: '796330625') }
  let(:claim) { build(:dependents_verification_claim) }

  before do
    sign_in_as(user)
    allow(DependentsVerification::Monitor).to receive(:new).and_return(monitor)
    allow(DependentsVerification::SavedClaim).to receive(:new).and_return(claim)
    allow(monitor).to receive_messages(track_show404: nil, track_show_error: nil, track_create_attempt: nil,
                                       track_create_error: nil, track_create_success: nil,
                                       track_create_validation_error: nil)
  end

  describe '#create' do
    let(:param_name) { :dependents_verification_claim }
    let(:form_id) { '21-0538' }
    let(:request) do
      post '/dependents_verification/v0/claims', params: { param_name => { form: claim.form } }
    end

    it 'logs validation errors' do
      allow(claim).to receive_messages(save: false, errors: 'mock error')

      expect(monitor).to receive(:track_create_attempt).once
      expect(monitor).to receive(:track_create_error).once
      expect(monitor).to receive(:track_create_validation_error).once

      request

      expect(response).to have_http_status(:internal_server_error)
    end

    context 'when the claim is valid' do
      context 'when the veteran file number is not present' do
        it 'returns a serialized claim' do
          allow(BGS::People::Request)
            .to receive(:new)
            .and_return(
              double(find_person_by_participant_id: double(file_number: nil))
            )
          request
          expect(response).to have_http_status(:success)
        end
      end

      context 'when the veteran file number is present' do
        context 'when the veteran file number does not contain dashes' do
          it 'returns a serialized claim' do
            VCR.use_cassette('bgs/people_service/person_data') do
              expect(monitor).to receive(:track_create_attempt).once
              expect(monitor).to receive(:track_create_success).once

              request

              expect(response).to have_http_status(:success)
            end
          end
        end

        context 'when the veteran file number contains dashes' do
          it 'returns a serialized claim' do
            allow(BGS::People::Request)
              .to receive(:new)
              .and_return(
                double(find_person_by_participant_id: double(file_number: '796-33-0625'))
              )
            request
            expect(response).to have_http_status(:success)
          end
        end
      end
    end
  end

  describe '#show' do
    it 'logs an error if no claim found' do
      expect(monitor).to receive(:track_show404).once

      get '/dependents_verification/v0/claims/:id', params: { id: 'non-existant-saved-claim' }

      expect(response).to have_http_status(:not_found)
    end

    it 'logs an error' do
      error = StandardError.new('Mock Error')
      allow(DependentsVerification::SavedClaim).to receive(:find_by!).and_raise(error)

      expect(monitor).to receive(:track_show_error).once

      get '/dependents_verification/v0/claims/:id', params: { id: 'non-existant-saved-claim' }

      expect(response).to have_http_status(:internal_server_error)
    end

    it 'returns a serialized claim' do
      claim = build(:dependents_verification_claim)
      allow(DependentsVerification::SavedClaim).to receive(:find_by!).and_return(claim)

      get '/dependents_verification/v0/claims/:id', params: { id: 'dependents_verification_claim' }

      expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq(claim.guid)
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#process_and_upload_to_lighthouse' do
    let(:claim) { build(:dependents_verification_claim) }
    let(:in_progress_form) { build(:in_progress_form) }
    let(:error) { StandardError.new('Something went wrong') }

    it 'returns a success' do
      expect(DependentsVerification::BenefitsIntake::SubmitClaimJob).to receive(:perform_async).with(claim.id)
      subject.send(:process_and_upload_to_lighthouse, claim)
    end
  end

  describe '#log_validation_error_to_metadata' do
    let(:claim) { build(:dependents_verification_claim) }
    let(:in_progress_form) { build(:in_progress_form) }

    it 'returns if a `blank` in_progress_form' do
      ['', [], {}, nil].each do |blank|
        expect(in_progress_form).not_to receive(:update)
        result = subject.send(:log_validation_error_to_metadata, blank, claim)
        expect(result).to be_nil
      end
    end

    it 'updates the in_progress_form' do
      expect(in_progress_form).to receive(:metadata).and_return(in_progress_form.metadata)
      expect(in_progress_form).to receive(:update)
      subject.send(:log_validation_error_to_metadata, in_progress_form, claim)
    end
  end

  # end RSpec.describe
end
