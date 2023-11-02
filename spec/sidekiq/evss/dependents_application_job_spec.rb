# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DependentsApplicationJob do
  describe '#perform' do
    let(:user) { create(:evss_user) }
    let!(:dependents_application) { create(:dependents_application, user:) }

    def reload_dependents_application
      DependentsApplication.find(dependents_application.id)
    end

    context 'when there is an error' do
      it 'sets the dependents_application to failed' do
        expect_any_instance_of(EVSS::Dependents::Service).to receive(:retrieve).and_raise('foo')
        begin
          described_class.drain
        rescue
          nil
        end
        dependents_application = reload_dependents_application
        expect(dependents_application.state).to eq('failed')
      end
    end

    it 'submits to the 686 api' do
      VCR.use_cassette(
        'evss/dependents/all',
        match_requests_on: %i[method uri body]
      ) do
        described_class.drain

        dependents_application = reload_dependents_application
        expect(dependents_application.state).to eq('success')
        expect(dependents_application.parsed_response).to eq(
          'submit686Response' => { 'confirmationNumber' => '600142587' }
        )
      end
    end

    context 'user info protection' do
      before { allow_any_instance_of(KmsEncrypted::Box).to receive(:decrypt).and_return(dependents_application.form) }

      it 'decrypts the encrypted user form argument' do
        VCR.use_cassette(
          'evss/dependents/all',
          match_requests_on: %i[method uri body]
        ) do
          expect_any_instance_of(KmsEncrypted::Box).to receive(:decrypt)
          described_class.drain
          reload_dependents_application
        end
      end

      it 'uses, then deletes a cache of user info' do
        VCR.use_cassette(
          'evss/dependents/all',
          match_requests_on: %i[method uri body]
        ) do
          expect_any_instance_of(EVSS::Dependents::RetrievedInfo).to receive(:body).once.and_call_original
          expect_any_instance_of(EVSS::Dependents::RetrievedInfo).to receive(:delete).once.and_call_original
          described_class.drain
        end
      end
    end
  end
end
