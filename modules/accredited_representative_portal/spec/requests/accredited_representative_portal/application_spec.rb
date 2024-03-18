# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::ApplicationController, type: :request do
  describe 'GET /accredited_representative_portal/arbitrary' do
    subject do
      get '/accredited_representative_portal/arbitrary'
      response
    end

    before(:context) do
      AccreditedRepresentativePortal::Engine.routes.draw do
        get 'arbitrary', to: 'arbitrary#arbitrary'
      end
    end

    after(:context) do
      # We could have set up our test such that we can unset
      # `ArbitraryController` as a const during cleanup. But we'll just leave it
      # around and avoid the extra metaprogramming.
      Rails.application.reload_routes!
    end

    describe 'when the accredited_representative_portal_api feature toggle' do
      before do
        expect(Flipper).to(
          receive(:enabled?)
            .with(:accredited_representative_portal_api)
            .and_return(enabled)
        )
      end

      describe 'is enabled' do
        let(:enabled) { true }

        it { is_expected.to have_http_status(:ok) }
      end

      describe 'is disabled' do
        let(:enabled) { false }

        it { is_expected.to have_http_status(:not_found) }
      end
    end
  end
end

module AccreditedRepresentativePortal
  class ArbitraryController < ApplicationController
    def arbitrary = head :ok
  end
end
