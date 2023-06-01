# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/sis_session_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.shared_examples 'sso logging' do |type|
  describe "#{type} logging" do
    before do
      allow(Rails.logger).to receive(:warn)

      if type == :sis
        @new_headers = sis_headers
      else
        @new_headers = iam_headers
        iam_sign_in
      end
    end

    it 'logs after create' do
      request.headers.merge! @new_headers
      post :create

      log_name = nil
      log_value = nil

      expect(Rails.logger).to have_received(:warn) do |name, value|
        log_name = name
        log_value = value.to_json
      end

      expect(log_name).to eq('Mobile::V0::ProfileBaseController#create request completed')
      expect(log_value).to match_json_schema('sso_log')
    end

    it 'logs after update' do
      request.headers.merge! @new_headers
      put :update, params: {
        id: 1
      }

      log_name = nil
      log_value = nil

      expect(Rails.logger).to have_received(:warn) do |name, value|
        log_name = name
        log_value = value.to_json
      end

      expect(log_name).to eq('Mobile::V0::ProfileBaseController#update request completed')
      expect(log_value).to match_json_schema('sso_log')
    end

    it 'logs after destroy' do
      request.headers.merge! @new_headers
      delete :destroy, params: {
        id: 1
      }

      log_name = nil
      log_value = nil

      expect(Rails.logger).to have_received(:warn) do |name, value|
        log_name = name
        log_value = value.to_json
      end

      expect(log_name).to eq('Mobile::V0::ProfileBaseController#destroy request completed')
      expect(log_value).to match_json_schema('sso_log')
    end
  end
end

RSpec.describe Mobile::V0::ProfileBaseController, type: :controller do
  include JsonSchemaMatchers

  controller do
    def create
      head :ok
    end

    def update
      head :ok
    end

    def destroy
      head :ok
    end
  end

  include_examples 'sso logging', :iam
  include_examples 'sso logging', :sis
end
