module LoadTesting
  class ApplicationController < ::ApplicationController
    protect_from_forgery with: :null_session
    
    skip_before_action :authenticate, if: -> { Rails.env.development? || Rails.env.test? }
    skip_before_action :verify_authenticity_token, if: -> { Rails.env.development? || Rails.env.test? }

    def current_user
      return nil if Rails.env.development? || Rails.env.test?
      super
    end
  end
end 