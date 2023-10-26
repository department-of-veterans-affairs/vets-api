# frozen_string_literal: true

require 'rails_helper'

class TaggedController < ApplicationController
  include Traceable
  skip_before_action :authenticate
  service_tag 'secure-messaging'

  def index
    render plain: 'OK'
  end
end

class UntaggedController < ApplicationController
  include Traceable
  skip_before_action :authenticate

  def index
    render plain: 'OK'
  end
end

class BaseController < ApplicationController
  include Traceable
  skip_before_action :authenticate

  def index
    render plain: 'BASE'
  end
end

class SubController < BaseController
  service_tag 'my-service'

  def index
    render plain: 'SUB'
  end
end

RSpec.describe Traceable, type: :controller do
  # Anonymous classes don't work with thread_mattr_accessor used in Traceable concern because
  # it derives a thread local variable from the class name, so define test classes here

  describe 'service_tag' do
    let(:mock_span) { double('Span') }

    before do
      allow(Datadog::Tracing).to receive(:active_span).and_return(mock_span)
      @controller = controller_class.new
    end

    after do
      Rails.application.reload_routes!
    end

    context 'when the service tag is present' do
      let(:controller_class) { TaggedController }

      before do
        Rails.application.routes.draw do
          get 'test', to: 'tagged#index'
        end
      end

      context 'with a service_tag' do
        it 'calls set_tags on the Datadog adapter via a before_action when and endpoint is hit' do
          expect(Datadog::Tracing.active_span).to receive(:service=).with('secure-messaging')
          get :index
          expect(response.body).to eq 'OK'
        end
      end

      context 'when an error occurs while setting trace tags' do
        before { allow(mock_span).to receive(:service=).and_raise(StandardError, 'Mock Error') }

        it 'logs "Error setting trace tags" and does not interrupt the response' do
          expect(Rails.logger).to receive(:error).with('Error setting service tag',
                                                       { class: 'TaggedController', message: 'Mock Error' })
          get :index
          expect(response.body).to eq 'OK'
        end
      end
    end

    context 'when the service tag is missing' do
      let(:controller_class) { UntaggedController }

      before do
        Rails.application.routes.draw do
          get 'test', to: 'untagged#index'
        end
      end

      it 'silently does not set a span tag' do
        expect(Datadog::Tracing.active_span).not_to receive(:service=)
        get :index
        expect(response.body).to eq 'OK'
      end
    end

    context 'with traceable parent controller' do
      let(:base_controller_class) { BaseController }
      let(:controller_class) { SubController }

      before do
        Rails.application.routes.draw do
          get 'test', to: 'sub#index'
        end
      end

      it 'calls set_tags on the span for the sub-controller' do
        expect(Datadog::Tracing.active_span).to receive(:service=).with('my-service')
        get :index
        expect(response.body).to eq 'SUB'
      end
    end
  end
end
