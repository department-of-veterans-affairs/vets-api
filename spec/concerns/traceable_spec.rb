# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Traceable, type: :controller do
  describe 'service_tag' do
    let(:mock_span) { double('Span') }

    before do
      allow(Datadog::Tracing).to receive(:active_span).and_return(mock_span)
      @controller = controller_class.new
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
          service_tag 'secure-messaging'

          def index
            render plain: 'OK'
          end
        end
      end

      context 'with a service_tag' do
        include_context 'stub controller'

        it 'calls set_tags on the Datadog adapter via a before_action when and endpoint is hit' do
          expect(Datadog::Tracing.active_span).to receive(:service=).with('secure-messaging')
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

      it 'silently does not set a span tag' do
        expect(Datadog::Tracing.active_span).not_to receive(:service=)
        get :index
        expect(response.body).to eq 'OK'
      end
    end

    context 'with untagged parent controller' do
      let(:base_class) do
        Class.new(ApplicationController) do
          include Traceable
          skip_before_action :authenticate

          def index
            render plain: 'BASE'
          end
        end
      end

      let(:controller_class) do
        Class.new(base_class) do
          service_tag 'my-service'

          def index
            render plain: 'SUB'
          end
        end
      end

      include_context 'stub controller'

      it 'calls set_tags on the span for the sub-controller' do
        expect(Datadog::Tracing.active_span).to receive(:service=).with('my-service')
        get :index
        expect(response.body).to eq 'SUB'
      end
    end

    context 'with tagged parent controller' do
      let(:base_class) do
        Class.new(ApplicationController) do
          include Traceable
          service_tag 'base-service'
          skip_before_action :authenticate

          def index
            render plain: 'BASE'
          end
        end
      end

      context 'with untagged child controller' do
        let(:controller_class) do
          Class.new(base_class) do
            def index
              render plain: 'SUB'
            end
          end
        end

        include_context 'stub controller'

        it 'child controller inherits parent tag' do
          expect(Datadog::Tracing.active_span).to receive(:service=).with('base-service')
          get :index
          expect(response.body).to eq 'SUB'
        end
      end

      context 'with tagged child controller' do
        let(:controller_class) do
          Class.new(base_class) do
            service_tag 'override-service'
            def index
              render plain: 'SUB'
            end
          end
        end

        include_context 'stub controller'

        it 'child controller overrides parent tag' do
          expect(Datadog::Tracing.active_span).to receive(:service=).with('override-service')
          get :index
          expect(response.body).to eq 'SUB'
        end
      end
    end
  end
end
