# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Traceable, type: :controller do
  describe 'service_tag' do
    let(:mock_span) { double('Span') }

    before do
      allow(Datadog::Tracing).to receive(:active_span).and_return(mock_span)
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

    context 'when the service tag is present' do
      let(:controller_class) do
        Class.new(ApplicationController) do
          include Traceable
          skip_before_action :authenticate
          service_tag :secure_messaging

          def index
            render plain: 'OK'
          end
        end
      end

      context 'with a service_tag' do
        include_context 'stub controller'

        it 'calls set_tags on the Datadog adapter via a before_action when and endpoint is hit' do
          expect(Datadog::Tracing.active_span).to receive(:service=).with(:secure_messaging)
          get :index
          expect(response.body).to eq 'OK'
        end
      end

      context 'when an error occurs while setting trace tags' do
        include_context 'stub controller'

        before { allow(mock_span).to receive(:service=).and_raise(StandardError, 'Mock Error') }

        it 'logs "Error setting trace tags" and does not interrupt the response' do
          expect(Rails.logger).to receive(:error).with('Error setting service tag',
                                                       { class: 'TestTraceableController', message: 'Mock Error' })
          get :index
          expect(response.body).to eq 'OK'
        end
      end
    end

    context 'when the service tag is missing' do
      let(:controller_class) do
        Class.new(ApplicationController) do
          include Traceable
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
