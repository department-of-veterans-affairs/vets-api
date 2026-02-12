# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::EventBusGatewayController, type: :controller do
  let(:participant_id) { '1234567890' }
  let(:template_id) { 'template_123' }
  let(:email_template_id) { 'email_template_456' }
  let(:push_template_id) { 'push_template_789' }

  let(:service_account_access_token) do
    instance_double(
      SignIn::ServiceAccountAccessToken,
      user_attributes: { 'participant_id' => participant_id }
    )
  end

  before do
    controller.instance_variable_set(:@service_account_access_token, service_account_access_token)
    allow(controller).to receive(:authenticate_service_account).and_return(true)
  end

  describe 'POST #send_email' do
    let(:params) { { template_id: } }

    it 'enqueues LetterReadyEmailJob with correct parameters' do
      expect(EventBusGateway::LetterReadyEmailJob)
        .to receive(:perform_async)
        .with(participant_id, template_id)

      post :send_email, params:
    end

    it 'returns 200 OK status' do
      allow(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async)

      post(:send_email, params:)

      expect(response).to have_http_status(:ok)
    end

    it 'returns no content in response body' do
      allow(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async)

      post(:send_email, params:)

      expect(response.body).to be_empty
    end

    context 'with missing template_id' do
      let(:params) { {} }

      it 'returns 400 Bad Request' do
        post(:send_email, params:)
        expect(response).to have_http_status(:bad_request)
      end

      it 'does not enqueue the job' do
        expect(EventBusGateway::LetterReadyEmailJob).not_to receive(:perform_async)
        post(:send_email, params:)
      end
    end

    context 'with additional unpermitted parameters' do
      let(:params) { { template_id:, extra_param: 'should_be_filtered' } }

      it 'filters out unpermitted parameters' do
        expect(EventBusGateway::LetterReadyEmailJob)
          .to receive(:perform_async)
          .with(participant_id, template_id)

        post :send_email, params:
      end
    end
  end

  describe 'POST #send_push' do
    let(:params) { { template_id: } }

    it 'enqueues LetterReadyPushJob with correct parameters' do
      expect(EventBusGateway::LetterReadyPushJob)
        .to receive(:perform_async)
        .with(participant_id, template_id)

      post :send_push, params:
    end

    it 'returns 200 OK status' do
      allow(EventBusGateway::LetterReadyPushJob).to receive(:perform_async)

      post(:send_push, params:)

      expect(response).to have_http_status(:ok)
    end

    it 'returns no content in response body' do
      allow(EventBusGateway::LetterReadyPushJob).to receive(:perform_async)

      post(:send_push, params:)

      expect(response.body).to be_empty
    end

    context 'with missing template_id' do
      let(:params) { {} }

      it 'returns 400 Bad Request' do
        post(:send_push, params:)
        expect(response).to have_http_status(:bad_request)
      end

      it 'does not enqueue the job' do
        expect(EventBusGateway::LetterReadyPushJob).not_to receive(:perform_async)
        post(:send_push, params:)
      end
    end

    context 'with additional unpermitted parameters' do
      let(:params) { { template_id:, malicious_param: 'filtered' } }

      it 'filters out unpermitted parameters' do
        expect(EventBusGateway::LetterReadyPushJob)
          .to receive(:perform_async)
          .with(participant_id, template_id)

        post :send_push, params:
      end
    end
  end

  describe 'POST #send_notifications' do
    context 'with both email and push template IDs' do
      let(:params) do
        {
          email_template_id:,
          push_template_id:
        }
      end

      it 'enqueues LetterReadyNotificationJob with correct parameters' do
        expect(EventBusGateway::LetterReadyNotificationJob)
          .to receive(:perform_async)
          .with(participant_id, email_template_id, push_template_id)

        post :send_notifications, params:
      end

      it 'returns 200 OK status' do
        allow(EventBusGateway::LetterReadyNotificationJob).to receive(:perform_async)

        post(:send_notifications, params:)

        expect(response).to have_http_status(:ok)
      end

      it 'returns no content in response body' do
        allow(EventBusGateway::LetterReadyNotificationJob).to receive(:perform_async)

        post(:send_notifications, params:)

        expect(response.body).to be_empty
      end
    end

    context 'with only email_template_id' do
      let(:params) { { email_template_id: } }

      it 'enqueues job with nil push_template_id' do
        expect(EventBusGateway::LetterReadyNotificationJob)
          .to receive(:perform_async)
          .with(participant_id, email_template_id, nil)

        post :send_notifications, params:
      end
    end

    context 'with only push_template_id' do
      let(:params) { { push_template_id: } }

      it 'enqueues job with nil email_template_id' do
        expect(EventBusGateway::LetterReadyNotificationJob)
          .to receive(:perform_async)
          .with(participant_id, nil, push_template_id)

        post :send_notifications, params:
      end
    end

    context 'with no template IDs' do
      let(:params) { {} }

      it 'returns 400 Bad Request' do
        post(:send_notifications, params:)
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error message about missing templates' do
        post(:send_notifications, params:)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['detail'])
          .to include('At least one of email_template_id or push_template_id is required')
      end

      it 'does not enqueue the job' do
        expect(EventBusGateway::LetterReadyNotificationJob).not_to receive(:perform_async)
        post(:send_notifications, params:)
      end
    end

    context 'with additional unpermitted parameters' do
      let(:params) do
        {
          email_template_id:,
          push_template_id:,
          unauthorized_param: 'should_not_pass'
        }
      end

      it 'filters out unpermitted parameters' do
        expect(EventBusGateway::LetterReadyNotificationJob)
          .to receive(:perform_async)
          .with(participant_id, email_template_id, push_template_id)

        post :send_notifications, params:
      end
    end
  end

  describe '#participant_id' do
    it 'extracts participant_id from service account access token' do
      expect(controller.send(:participant_id)).to eq(participant_id)
    end

    it 'memoizes the participant_id' do
      expect(service_account_access_token).to receive(:user_attributes).once.and_return(
        { 'participant_id' => participant_id }
      )

      controller.send(:participant_id)
      controller.send(:participant_id)
    end

    context 'when participant_id is not in token attributes' do
      let(:service_account_access_token) do
        instance_double(
          SignIn::ServiceAccountAccessToken,
          user_attributes: {}
        )
      end

      before do
        controller.instance_variable_set(:@service_account_access_token, service_account_access_token)
      end

      it 'returns nil' do
        expect(controller.send(:participant_id)).to be_nil
      end
    end
  end

  describe 'authentication' do
    context 'when service account authentication fails' do
      before do
        allow(controller).to receive(:authenticate_service_account) do
          controller.render json: { errors: 'Unauthorized' }, status: :unauthorized
          false
        end
      end

      it 'does not enqueue email job' do
        expect(EventBusGateway::LetterReadyEmailJob).not_to receive(:perform_async)

        post :send_email, params: { template_id: }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not enqueue push job' do
        expect(EventBusGateway::LetterReadyPushJob).not_to receive(:perform_async)

        post :send_push, params: { template_id: }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not enqueue notification job' do
        expect(EventBusGateway::LetterReadyNotificationJob).not_to receive(:perform_async)

        post :send_notifications, params: {
          email_template_id:,
          push_template_id:
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'service tagging' do
    it 'has the correct service tag' do
      expect(described_class.trace_service_tag).to eq('event_bus_gateway')
    end
  end

  describe '#select_email_template' do
    let(:decision_letter_template_id) { 'decision_letter_template_123' }
    let(:universal_link_template_id) { 'universal_link_template_456' }
    let(:other_template_id) { 'some_other_template_789' }

    before do
      allow(Settings.vanotify.services.benefits_management_tools.template_id)
        .to receive(:decision_letter_ready_email).and_return(decision_letter_template_id)
      allow(Settings.vanotify.services.benefits_management_tools.template_id)
        .to receive(:decision_letter_ready_email_universal_link).and_return(universal_link_template_id)
    end

    context 'when template is decision letter and universal link is enabled' do
      before do
        allow(controller).to receive(:universal_link_enabled?).and_return(true)
      end

      it 'returns universal link template' do
        result = controller.send(:select_email_template, decision_letter_template_id)
        expect(result).to eq(universal_link_template_id)
      end

      it 'logs the template selection' do
        expect(Rails.logger).to receive(:info).with(
          'EventBusGatewayController using universal link template',
          {
            original_template: decision_letter_template_id,
            universal_link_template: universal_link_template_id
          }
        )

        controller.send(:select_email_template, decision_letter_template_id)
      end
    end

    context 'when template is decision letter but universal link is disabled' do
      before do
        allow(controller).to receive(:universal_link_enabled?).and_return(false)
      end

      it 'returns original template' do
        result = controller.send(:select_email_template, decision_letter_template_id)
        expect(result).to eq(decision_letter_template_id)
      end

      it 'does not log template selection' do
        expect(Rails.logger).not_to receive(:info)
        controller.send(:select_email_template, decision_letter_template_id)
      end
    end

    context 'when template is not a decision letter' do
      before do
        allow(controller).to receive(:universal_link_enabled?).and_return(true)
      end

      it 'returns original template' do
        result = controller.send(:select_email_template, other_template_id)
        expect(result).to eq(other_template_id)
      end

      it 'does not check universal link enabled' do
        expect(controller).not_to receive(:universal_link_enabled?)
        controller.send(:select_email_template, other_template_id)
      end
    end

    context 'when universal link template is not configured' do
      before do
        allow(Settings.vanotify.services.benefits_management_tools.template_id)
          .to receive(:decision_letter_ready_email_universal_link).and_return(nil)
        allow(controller).to receive(:universal_link_enabled?).and_return(true)
      end

      it 'returns original template' do
        result = controller.send(:select_email_template, decision_letter_template_id)
        expect(result).to eq(decision_letter_template_id)
      end
    end

    context 'when universal link template is empty string' do
      before do
        allow(Settings.vanotify.services.benefits_management_tools.template_id)
          .to receive(:decision_letter_ready_email_universal_link).and_return('')
        allow(controller).to receive(:universal_link_enabled?).and_return(true)
      end

      it 'returns original template' do
        result = controller.send(:select_email_template, decision_letter_template_id)
        expect(result).to eq(decision_letter_template_id)
      end
    end
  end

  describe '#universal_link_enabled?' do
    let(:flipper_actor) { instance_double(Flipper::Actor) }

    before do
      allow(Flipper::Actor).to receive(:new).with(participant_id).and_return(flipper_actor)
    end

    context 'when flipper flag is enabled for participant' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:event_bus_gateway_letter_ready_email_universal_link, flipper_actor)
          .and_return(true)
      end

      it 'returns true' do
        expect(controller.send(:universal_link_enabled?)).to be true
      end

      it 'creates flipper actor with participant_id' do
        expect(Flipper::Actor).to receive(:new).with(participant_id)
        controller.send(:universal_link_enabled?)
      end
    end

    context 'when flipper flag is disabled for participant' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:event_bus_gateway_letter_ready_email_universal_link, flipper_actor)
          .and_return(false)
      end

      it 'returns false' do
        expect(controller.send(:universal_link_enabled?)).to be false
      end
    end
  end

  describe '#process_email_template' do
    let(:decision_letter_template_id) { 'decision_letter_template_123' }
    let(:universal_link_template_id) { 'universal_link_template_456' }

    before do
      allow(Settings.vanotify.services.benefits_management_tools.template_id)
        .to receive(:decision_letter_ready_email).and_return(decision_letter_template_id)
      allow(Settings.vanotify.services.benefits_management_tools.template_id)
        .to receive(:decision_letter_ready_email_universal_link).and_return(universal_link_template_id)
      allow(Flipper).to receive(:enabled?).and_return(false)
    end

    context 'for send_email action' do
      it 'processes template_id from params' do
        allow(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async)

        post :send_email, params: { template_id: decision_letter_template_id }

        expect(controller.instance_variable_get(:@final_email_template_id)).to eq(decision_letter_template_id)
      end

      context 'when universal link is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_return(true)
        end

        it 'sets final template to universal link template' do
          allow(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async)

          post :send_email, params: { template_id: decision_letter_template_id }

          expect(controller.instance_variable_get(:@final_email_template_id)).to eq(universal_link_template_id)
        end

        it 'enqueues job with universal link template' do
          expect(EventBusGateway::LetterReadyEmailJob)
            .to receive(:perform_async)
            .with(participant_id, universal_link_template_id)

          post :send_email, params: { template_id: decision_letter_template_id }
        end
      end
    end

    context 'for send_notifications action' do
      it 'processes email_template_id from params' do
        allow(EventBusGateway::LetterReadyNotificationJob).to receive(:perform_async)

        post :send_notifications, params: { email_template_id: decision_letter_template_id }

        expect(controller.instance_variable_get(:@final_email_template_id)).to eq(decision_letter_template_id)
      end

      context 'when universal link is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_return(true)
        end

        it 'sets final template to universal link template' do
          allow(EventBusGateway::LetterReadyNotificationJob).to receive(:perform_async)

          post :send_notifications, params: { email_template_id: decision_letter_template_id }

          expect(controller.instance_variable_get(:@final_email_template_id)).to eq(universal_link_template_id)
        end

        it 'enqueues job with universal link template' do
          expect(EventBusGateway::LetterReadyNotificationJob)
            .to receive(:perform_async)
            .with(participant_id, universal_link_template_id, nil)

          post :send_notifications, params: { email_template_id: decision_letter_template_id }
        end
      end

      context 'when email_template_id is nil' do
        it 'sets final template to nil' do
          allow(EventBusGateway::LetterReadyNotificationJob).to receive(:perform_async)

          post :send_notifications, params: { push_template_id: }

          expect(controller.instance_variable_get(:@final_email_template_id)).to be_nil
        end

        it 'does not call select_email_template' do
          allow(EventBusGateway::LetterReadyNotificationJob).to receive(:perform_async)

          expect(controller).not_to receive(:select_email_template)

          post :send_notifications, params: { push_template_id: }
        end
      end
    end
  end
end
