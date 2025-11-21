# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vass::ApplicationController, type: :controller do
  describe 'inheritance and configuration' do
    it 'inherits from ::ApplicationController' do
      expect(Vass::ApplicationController.superclass).to eq(ApplicationController)
    end

    it 'includes ExceptionHandling concern from parent' do
      expect(Vass::ApplicationController.ancestors).to include(ExceptionHandling)
    end

    it 'configures service tag to vass' do
      # Service tag is set via the service_tag method from Traceable concern
      # We verify the instance variable is set on the class
      expect(Vass::ApplicationController.trace_service_tag).to eq('vass')
    end
  end

  describe 'error handling methods' do
    let(:controller) { Vass::ApplicationController.new }

    it 'defines cors_preflight method' do
      expect(controller).to respond_to(:cors_preflight)
    end

    it 'defines handle_authentication_error method' do
      expect(controller.private_methods).to include(:handle_authentication_error)
    end

    it 'defines handle_not_found_error method' do
      expect(controller.private_methods).to include(:handle_not_found_error)
    end

    it 'defines handle_validation_error method' do
      expect(controller.private_methods).to include(:handle_validation_error)
    end

    it 'defines handle_service_error method' do
      expect(controller.private_methods).to include(:handle_service_error)
    end

    it 'defines handle_vass_api_error method' do
      expect(controller.private_methods).to include(:handle_vass_api_error)
    end

    it 'defines handle_redis_error method' do
      expect(controller.private_methods).to include(:handle_redis_error)
    end

    it 'defines render_error_response method' do
      expect(controller.private_methods).to include(:render_error_response)
    end

    it 'defines log_safe_error method' do
      expect(controller.private_methods).to include(:log_safe_error)
    end
  end

  describe 'rescue_from handlers' do
    it 'rescues from Vass::Errors::AuthenticationError' do
      handlers = Vass::ApplicationController.rescue_handlers
      auth_error_handler = handlers.find { |h| h.first == 'Vass::Errors::AuthenticationError' }
      expect(auth_error_handler).not_to be_nil
    end

    it 'rescues from Vass::Errors::NotFoundError' do
      handlers = Vass::ApplicationController.rescue_handlers
      not_found_handler = handlers.find { |h| h.first == 'Vass::Errors::NotFoundError' }
      expect(not_found_handler).not_to be_nil
    end

    it 'rescues from Vass::Errors::ValidationError' do
      handlers = Vass::ApplicationController.rescue_handlers
      validation_handler = handlers.find { |h| h.first == 'Vass::Errors::ValidationError' }
      expect(validation_handler).not_to be_nil
    end

    it 'rescues from Vass::Errors::ServiceError' do
      handlers = Vass::ApplicationController.rescue_handlers
      service_handler = handlers.find { |h| h.first == 'Vass::Errors::ServiceError' }
      expect(service_handler).not_to be_nil
    end

    it 'rescues from Vass::Errors::VassApiError' do
      handlers = Vass::ApplicationController.rescue_handlers
      api_handler = handlers.find { |h| h.first == 'Vass::Errors::VassApiError' }
      expect(api_handler).not_to be_nil
    end

    it 'rescues from Vass::Errors::RedisError' do
      handlers = Vass::ApplicationController.rescue_handlers
      redis_handler = handlers.find { |h| h.first == 'Vass::Errors::RedisError' }
      expect(redis_handler).not_to be_nil
    end
  end
end
