module LoadTesting
  module V0
    class TokensController < ApplicationController
      def next
        test_session = TestSession.find(params[:id])
        token = test_session.test_tokens.where('expires_at > ?', 5.minutes.from_now).first
        
        if token.nil?
          token = TokenManager.new(test_session).generate_tokens(1).first
        end
        
        render json: token
      end
    end
  end
end 