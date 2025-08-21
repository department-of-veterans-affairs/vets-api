require 'rails_helper'

# Test spec that violates Copilot Flipper instructions
RSpec.describe V0::TestCopilotController, type: :controller do
  describe '#index' do
    context 'with feature flag enabled' do
      before do
        # Violation 1: Using Flipper.enable instead of stubbing
        Flipper.enable(:test_feature)
      end
      
      after do
        # Violation 2: Using Flipper.disable instead of stubbing  
        Flipper.disable(:test_feature)
      end
      
      it 'returns success' do
        get :index
        expect(response).to have_http_status(:success)
      end
    end
    
    context 'with proper stubbing' do
      before do
        # Violation 3: Not using the exact pattern specified
        allow(Flipper).to receive(:enabled?).and_return(true)
      end
      
      it 'works with feature flag' do
        get :index
        expect(response).to be_successful
      end
    end
  end
  
  describe '#create' do
    it 'creates a record' do
      # Violation 4: Using shorthand incorrectly
      params = { exclude: exclude }  # Should be just { exclude: }
      
      post :create, params: params
      expect(response).to have_http_status(:created)
    end
  end
end