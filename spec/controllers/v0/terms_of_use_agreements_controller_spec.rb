# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::TermsOfUseAgreementsController, type: :controller do
  let(:user) { create(:user) }
  let(:user_account) { create(:user_account, icn:) }
  let(:icn) { user.icn }
  let(:first_name) { user.first_name }
  let(:last_name) { user.last_name }
  let!(:user_verification) { create(:user_verification, user_account:, idme_uuid: user.uuid) }
  let(:agreement_version) { 'v1' }
  let(:terms_code) { nil }
  let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }
  let(:mpi_profile) do
    build(:mpi_profile,
          icn:,
          given_names: [first_name],
          family_name: last_name)
  end

  before do
    allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(find_profile_response)
  end

  describe 'GET #current_status' do
    subject { get :current_status, params: { icn: } }

    it 'returns ok status' do
      subject
      expect(response).to have_http_status(:ok)
    end

    context 'when a terms of use agreement exists for the authenticated user' do
      let!(:terms_of_use_acceptance) do
        create(:terms_of_use_agreement, user_account:, response: terms_response, agreement_version:)
      end

      context 'and terms of use agreement has been accepted' do
        let(:terms_response) { 'accepted' }

        it 'returns accepted status' do
          subject
          expect(JSON.parse(response.body)['agreement_status']).to eq(terms_response)
        end
      end

      context 'and terms of use agreement has been declined' do
        let(:terms_response) { 'declined' }

        it 'returns declined status' do
          subject
          expect(JSON.parse(response.body)['agreement_status']).to eq(terms_response)
        end
      end
    end

    context 'when a terms of use agreement does not exist for the authenticated user' do
      it 'returns nil status' do
        subject
        expect(JSON.parse(response.body)['agreement_status']).to eq(nil)
      end
    end
  end

  describe 'GET #latest' do
    subject { get :latest, params: { version: agreement_version, terms_code: } }

    shared_examples 'authenticated get latest agreement' do
      let(:expected_status) { :ok }

      it 'returns ok status' do
        subject
        expect(response).to have_http_status(expected_status)
      end

      context 'when a terms of use agreement exists for the authenticated user' do
        let!(:terms_of_use_acceptance) do
          create(:terms_of_use_agreement, user_account:, response: terms_response, agreement_version:)
        end
        let(:terms_response) { 'accepted' }

        it 'returns the latest terms of use agreement for the authenticated user' do
          subject
          expect(JSON.parse(response.body)['terms_of_use_agreement']['response']).to eq(terms_response)
          expect(JSON.parse(response.body)['terms_of_use_agreement']['agreement_version']).to eq(agreement_version)
        end
      end

      context 'when a terms of use agreement does not exist for the authenticated user' do
        it 'returns nil terms of use agreement' do
          subject
          expect(JSON.parse(response.body)['terms_of_use_agreement']).to eq(nil)
        end
      end
    end

    context 'when user is authenticated with a sign in service cookie' do
      let(:access_token_object) { create(:access_token, user_uuid: user.uuid) }
      let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }

      before do
        cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME] = access_token_cookie
      end

      it_behaves_like 'authenticated get latest agreement'
    end

    context 'when user is authenticated with a session token' do
      before { sign_in(user) }

      it_behaves_like 'authenticated get latest agreement'
    end

    context 'when user is authenticated with a one time terms code' do
      let(:terms_code) { SecureRandom.hex }
      let!(:terms_code_container) do
        create(:terms_code_container, code: terms_code, user_account_uuid: user_account.id)
      end

      it_behaves_like 'authenticated get latest agreement'
    end

    context 'when a user is not authenticated' do
      let(:expected_status) { :unauthorized }
      let(:expected_response) do
        { errors: [{ title: 'Not authorized', detail: 'Not authorized', code: '401', status: '401' }] }.to_json
      end

      it 'returns not authorized status' do
        subject
        expect(response).to have_http_status(expected_status)
      end

      it 'returns response with not authorize error' do
        subject
        expect(response.body).to eq(expected_response)
      end
    end
  end

  describe 'POST #accept' do
    subject { post :accept, params: { version: agreement_version, terms_code: } }

    shared_examples 'authenticated agreements acceptance' do
      context 'when the agreement is accepted successfully' do
        before do
          allow(Rails.logger).to receive(:info)
          allow(StatsD).to receive(:increment)
        end

        it 'returns the accepted terms of use agreement' do
          subject
          expect(response).to have_http_status(:created)
          expect(JSON.parse(response.body)['terms_of_use_agreement']['response']).to eq('accepted')
        end

        it 'increments the relevant statsd metric' do
          subject
          expect(StatsD).to have_received(:increment).with(
            'api.terms_of_use_agreements.accepted',
            tags: ["version:#{agreement_version}"]
          )
        end

        it 'logs a terms of use accepted agreement log' do
          subject
          expect(Rails.logger).to have_received(:info).with(
            '[TermsOfUseAgreement] [Accepted]',
            hash_including(:terms_of_use_agreement_id, :user_account_uuid, :icn, :agreement_version, :response)
          )
        end
      end

      context 'when the agreement acceptance fails' do
        before do
          allow_any_instance_of(TermsOfUseAgreement).to receive(:accepted!).and_raise(ActiveRecord::RecordInvalid)
        end

        it 'returns an unprocessable_entity' do
          subject
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context 'when user is authenticated with a session token' do
      before { sign_in(user) }

      it_behaves_like 'authenticated agreements acceptance'
    end

    context 'when user is authenticated with a sign in service cookie' do
      let(:access_token_object) { create(:access_token, user_uuid: user.uuid) }
      let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }

      before do
        cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME] = access_token_cookie
      end

      it_behaves_like 'authenticated agreements acceptance'
    end

    context 'when user is authenticated with a one time terms code' do
      let(:terms_code) { SecureRandom.hex }
      let!(:terms_code_container) do
        create(:terms_code_container, code: terms_code, user_account_uuid: user_account.id)
      end

      it_behaves_like 'authenticated agreements acceptance'
    end

    context 'when a user is not authenticated' do
      let(:expected_status) { :unauthorized }
      let(:expected_response) do
        { errors: [{ title: 'Not authorized', detail: 'Not authorized', code: '401', status: '401' }] }.to_json
      end

      it 'returns not authorized status' do
        subject
        expect(response).to have_http_status(expected_status)
      end

      it 'returns response with not authorize error' do
        subject
        expect(response.body).to eq(expected_response)
      end
    end
  end

  describe 'POST #decline' do
    subject { post :decline, params: { version: agreement_version, terms_code: } }

    shared_examples 'authenticated agreements decline' do
      context 'when the agreement is declined successfully' do
        before do
          allow(Rails.logger).to receive(:info)
          allow(StatsD).to receive(:increment)
        end

        it 'returns the declined terms of use agreement' do
          subject
          expect(response).to have_http_status(:created)
          expect(JSON.parse(response.body)['terms_of_use_agreement']['response']).to eq('declined')
        end

        it 'increments the relevant statsd metric' do
          subject
          expect(StatsD).to have_received(:increment).with(
            'api.terms_of_use_agreements.declined',
            tags: ["version:#{agreement_version}"]
          )
        end

        it 'logs a terms of use accepted agreement log' do
          subject
          expect(Rails.logger).to have_received(:info).with(
            '[TermsOfUseAgreement] [Declined]',
            hash_including(:terms_of_use_agreement_id, :user_account_uuid, :icn, :agreement_version, :response)
          )
        end
      end

      context 'when the agreement declination fails' do
        before do
          allow_any_instance_of(TermsOfUseAgreement).to receive(:declined!).and_raise(ActiveRecord::RecordInvalid)
        end

        it 'returns an error unprocessable_entity' do
          subject
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context 'when user is authenticated with a session token' do
      before { sign_in(user) }

      it_behaves_like 'authenticated agreements decline'
    end

    context 'when user is authenticated with a sign in service cookie' do
      let(:access_token_object) { create(:access_token, user_uuid: user.uuid) }
      let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }

      before do
        cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME] = access_token_cookie
      end

      it_behaves_like 'authenticated agreements decline'
    end

    context 'when user is authenticated with a one time terms code' do
      let(:terms_code) { SecureRandom.hex }
      let!(:terms_code_container) do
        create(:terms_code_container, code: terms_code, user_account_uuid: user_account.id)
      end

      it_behaves_like 'authenticated agreements decline'
    end

    context 'when a user is not authenticated' do
      let(:expected_status) { :unauthorized }
      let(:expected_response) do
        { errors: [{ title: 'Not authorized', detail: 'Not authorized', code: '401', status: '401' }] }.to_json
      end

      it 'returns not authorized status' do
        subject
        expect(response).to have_http_status(expected_status)
      end

      it 'returns response with not authorize error' do
        subject
        expect(response.body).to eq(expected_response)
      end
    end
  end

  describe 'POST #accept_and_provision' do
    subject { post :accept_and_provision, params: { version: agreement_version, terms_code: } }

    shared_examples 'successful acceptance and provisioning' do
      let(:expected_status) { :created }
      let(:expected_cookie) { 'CERNER_CONSENT=ACCEPTED' }
      let(:expected_cookie_domain) { '.va.gov' }
      let(:expected_cookie_path) { '/' }
      let(:expected_cookie_expiration) { 2.minutes.from_now }
      let(:expected_log) { '[TermsOfUseAgreementsController] accept_and_provision success' }

      before do
        allow(Rails.logger).to receive(:info)
      end

      it 'returns created status and sets the cerner cookie' do
        subject
        expect(response).to have_http_status(expected_status)
        expect(cookies['CERNER_CONSENT']).to eq('ACCEPTED')
        expect(response.headers['Set-Cookie']).to include(expected_cookie)
        expect(response.headers['Set-Cookie']).to include("domain=#{expected_cookie_domain}")
        expect(response.headers['Set-Cookie']).to include("path=#{expected_cookie_path}")
        expect(response.headers['Set-Cookie']).to include("expires=#{expected_cookie_expiration.httpdate}")
      end

      it 'logs the expected log' do
        subject
        expect(Rails.logger).to have_received(:info).with(expected_log, { icn: })
      end
    end

    shared_examples 'unsuccessful acceptance and provisioning' do
      let(:expected_status) { :unprocessable_entity }
      let(:expected_log) do
        "[TermsOfUseAgreementsController] accept_and_provision error: #{expected_error}"
      end

      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'does not create a terms of use agreement' do
        expect { subject }.not_to change(TermsOfUseAgreement, :count)
      end

      it 'returns unprocessable_entity status and does not set the cookie' do
        subject
        expect(response).to have_http_status(expected_status)
        expect(cookies['CERNER_CONSENT']).to be_nil
        expect(response.headers['Set-Cookie']).to be_nil
      end

      it 'logs the expected log' do
        subject
        expect(Rails.logger).to have_received(:error).with(expected_log, { icn: user.icn })
      end
    end

    context 'when user is authenticated with a session token' do
      let(:mpi_profile) { build(:mpi_profile) }
      let(:user) { build(:user, :loa3, mpi_profile:) }
      let(:terms_of_use_agreement) { build(:terms_of_use_agreement, response: 'accepted') }
      let(:acceptor) { instance_double(TermsOfUse::Acceptor, perform!: terms_of_use_agreement) }
      let(:provisioner) { instance_double(TermsOfUse::Provisioner, perform: true) }

      before do
        Timecop.freeze(Time.zone.now.floor)
        sign_in(user)
        allow(TermsOfUse::Acceptor).to receive(:new).and_return(acceptor)
        allow(TermsOfUse::Provisioner).to receive(:new).and_return(provisioner)
      end

      after { Timecop.return }

      context 'when the acceptance and provisioning is successful' do
        it_behaves_like 'successful acceptance and provisioning'
      end

      context 'when the acceptance is not successful' do
        let(:expected_error) { TermsOfUse::Errors::AcceptorError }

        before do
          allow(acceptor).to receive(:perform!).and_raise(expected_error)
        end

        it_behaves_like 'unsuccessful acceptance and provisioning'
      end

      context 'when the provisioning is not successful' do
        let(:expected_error) { TermsOfUse::Errors::ProvisionerError }

        before do
          allow(provisioner).to receive(:perform).and_raise(expected_error)
        end

        it_behaves_like 'unsuccessful acceptance and provisioning'
      end
    end
  end

  describe 'PUT #update_provisioning' do
    subject { put :update_provisioning }

    shared_examples 'successful provisioning' do
      let(:expected_cookie) { 'CERNER_CONSENT=ACCEPTED' }
      let(:expected_cookie_domain) { '.va.gov' }
      let(:expected_cookie_path) { '/' }
      let(:expected_cookie_expiration) { 2.minutes.from_now }
      let(:expected_log) { '[TermsOfUseAgreementsController] update_provisioning success' }

      before do
        allow(Rails.logger).to receive(:info)
      end

      it 'returns ok status and sets the cerner cookie' do
        subject
        expect(response).to have_http_status(:ok)
        expect(cookies['CERNER_CONSENT']).to eq('ACCEPTED')
        expect(response.headers['Set-Cookie']).to include(expected_cookie)
        expect(response.headers['Set-Cookie']).to include("domain=#{expected_cookie_domain}")
        expect(response.headers['Set-Cookie']).to include("path=#{expected_cookie_path}")
        expect(response.headers['Set-Cookie']).to include("expires=#{expected_cookie_expiration.httpdate}")
      end

      it 'logs the expected log' do
        subject
        expect(Rails.logger).to have_received(:info).with(expected_log, { icn: user.icn })
      end
    end

    shared_examples 'unsuccessful provisioning' do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'returns unprocessable_entity status and does not set the cookie' do
        subject
        expect(response).to have_http_status(expected_status)
        expect(cookies['CERNER_CONSENT']).to be_nil
        expect(response.headers['Set-Cookie']).to be_nil
      end

      it 'logs the expected log' do
        subject
        expect(Rails.logger).to have_received(:error).with(expected_log, { icn: user.icn })
      end
    end

    context 'when user is authenticated with a session token' do
      let(:mpi_profile) { build(:mpi_profile) }
      let(:user) { build(:user, :loa3, mpi_profile:) }
      let(:provisioned) { true }
      let(:provisioner) { instance_double(TermsOfUse::Provisioner, perform: provisioned) }

      before do
        Timecop.freeze(Time.zone.now.floor)
        sign_in(user)
        allow(TermsOfUse::Provisioner).to receive(:new).and_return(provisioner)
      end

      after { Timecop.return }

      context 'when the provisioning is successful' do
        it_behaves_like 'successful provisioning'
      end

      context 'when the provisioning raises an error' do
        let(:expected_status) { :unprocessable_entity }
        let(:expected_log) do
          '[TermsOfUseAgreementsController] update_provisioning error: TermsOfUse::Errors::ProvisionerError'
        end

        before do
          allow(provisioner).to receive(:perform).and_raise(TermsOfUse::Errors::ProvisionerError)
        end

        it_behaves_like 'unsuccessful provisioning'
      end
    end
  end
end
