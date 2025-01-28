# frozen_string_literal: true

require "rails_helper"
require "va_notify/default_callback"

RSpec.describe "VANotify Callbacks", type: :request do
  let(:multiple_tokens) { Settings.vanotify.service_callback_tokens }
  let(:valid_token) { Settings.vanotify.status_callback.bearer_token }
  let(:invalid_token) { "invalid_token" }
  let(:notification_id) { SecureRandom.uuid }
  let(:callback_params) do
    {
      id: notification_id,
      status: "delivered",
      notification_type: "email",
      to: "user@example.com"
    }
  end
  let(:callback_route) { "/va_notify/callbacks" }

  describe "POST #create" do
    context "with found notification" do
      it "updates notification" do
        allow(Flipper).to receive(:enabled?).with(:va_notify_custom_bearer_tokens).and_return(false)
        template_id = SecureRandom.uuid
        notification = VANotify::Notification.create(notification_id: notification_id,
          source_location: "some_location",
          callback_metadata: "some_callback_metadata",
          template_id: template_id)
        expect(notification.status).to be_nil
        allow(Rails.logger).to receive(:info)
        callback_obj = double("VANotify::DefaultCallback")
        allow(VANotify::DefaultCallback).to receive(:new).and_return(callback_obj)
        allow(callback_obj).to receive(:call)

        post(callback_route,
          params: callback_params.to_json,
          headers: {"Authorization" => "Bearer #{valid_token}", "Content-Type" => "application/json"})

        expect(Rails.logger).to have_received(:info).with(
          "va_notify callbacks - Updating notification: #{notification.id}",
          {source_location: "some_location", template_id: template_id, callback_metadata: "some_callback_metadata",
           status: "delivered"}
        )
        expect(response.body).to include("success")
        notification.reload
        expect(notification.status).to eq("delivered")
      end
    end

    context "with missing notification" do
      it "logs info" do
        allow(Flipper).to receive(:enabled?).with(:va_notify_custom_bearer_tokens).and_return(false)
        allow(Rails.logger).to receive(:info)
        post(callback_route,
          params: callback_params.to_json,
          headers: {"Authorization" => "Bearer #{valid_token}", "Content-Type" => "application/json"})

        expect(Rails.logger).to have_received(:info).with(
          "va_notify callbacks - Received update for unknown notification #{notification_id}"
        )

        expect(response.body).to include("success")
      end
    end

    context "with valid token" do
      it "returns http success" do
        allow(Flipper).to receive(:enabled?).with(:va_notify_custom_bearer_tokens).and_return(false)
        post(callback_route,
          params: callback_params.to_json,
          headers: {"Authorization" => "Bearer #{valid_token}", "Content-Type" => "application/json"})
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("success")
      end
    end

    context "with invalid token" do
      it "returns http unauthorized" do
        post(callback_route,
          params: callback_params.to_json,
          headers: {"Authorization" => "Bearer #{invalid_token}", "Content-Type" => "application/json"})

        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to include("Unauthorized")
      end
    end

    context "without a token" do
      it "returns http unauthorized" do
        post(callback_route,
          params: callback_params,
          headers: {"Content-Type" => "application/json"})
        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to include("Unauthorized")
      end
    end

    context "with multiple bearer tokens" do
      it "authenticates a valid token" do
        allow(Flipper).to receive(:enabled?).with(:va_notify_custom_bearer_tokens).and_return(true)
        allow(Rails.logger).to receive(:info)
        service_specific_bearer_token = Settings.vanotify.service_callback_tokens.service_name

        post(callback_route,
          params: callback_params.to_json,
          headers: {"Authorization" => "Bearer #{service_specific_bearer_token}", "Content-Type" => "application/json"})

        expect(response).to have_http_status(:ok)
      end

      it "does not authenticates invalid token" do
        allow(Flipper).to receive(:enabled?).with(:va_notify_custom_bearer_tokens).and_return(true)
        allow(Rails.logger).to receive(:info)

        post(callback_route,
          params: callback_params.to_json,
          headers: {"Authorization" => "Bearer #{invalid_token}", "Content-Type" => "application/json"})

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
