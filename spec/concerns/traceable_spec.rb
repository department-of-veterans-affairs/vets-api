# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Traceable, type: :controller do
  describe 'service_tag' do
    let(:controller_class) do
      Class.new(ApplicationController) do
        skip_before_action :authenticate
        service_tag :secure_messaging

        def index
          render plain: 'OK'
        end
      end
    end

    after do
      Rails.application.reload_routes!
    end

    shared_context 'stub controller' do
      before do
        stub_const('TestTraceableController', controller_class)

        Rails.application.routes.draw do
          get 'test_traceable', to: 'test_traceable#index'
        end

        @controller = controller_class.new
      end
    end

    context 'with a valid service_tag' do
      include_context 'stub controller'

      before { allow(Tracers::DatadogAdapter).to receive(:set_service_tag) }

      it 'calls set_tags on the Datadog adapter via a before_action when and endpoint is hit' do
        expect(Tracers::DatadogAdapter).to receive(:set_service_tag).with(:secure_messaging)
        get :index
        expect(response.body).to eq 'OK'
      end
    end

    context 'with an invalid service_tag' do
      let(:controller_class) do
        Class.new(ApplicationController) do
          skip_before_action :authenticate
          service_tag :invalid_service_tag

          def index
            render plain: 'OK'
          end
        end
      end

      it 'handles the error' do
        expect do
          controller_class.new
        end.to raise_error(RuntimeError, 'Invalid service tag in Class: invalid_service_tag')
      end
    end

    context 'when an error occurs while setting trace tags' do
      include_context 'stub controller'

      before { allow(Tracers::DatadogAdapter).to receive(:set_service_tag).and_raise(StandardError, 'Mock Error') }

      it 'logs "Error setting trace tags" and does not interrupt the response' do
        expect(Rails.logger).to receive(:error).with('Error setting service tag',
                                                     { class: 'TestTraceableController', message: 'Mock Error' })
        get :index
        expect(response.body).to eq 'OK'
      end
    end

    context 'when the service tag is missing' do
      let(:controller_class) do
        Class.new(ApplicationController) do
          skip_before_action :authenticate

          def index
            render plain: 'OK'
          end
        end
      end

      include_context 'stub controller'

      it 'logs "Trace tag for service missing"' do
        expect(Rails.logger).to receive(:warn).with('Service tag missing', { class: 'TestTraceableController' })
        get :index
        expect(response.body).to eq 'OK'
      end
    end
  end
end
