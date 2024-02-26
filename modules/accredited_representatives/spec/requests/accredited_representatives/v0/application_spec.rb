# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentatives::V0::ApplicationController, type: :request do
  path_suffix = 'arbitrary'
  path = "/accredited_representatives/v0/#{path_suffix}"

  describe "GET #{path}" do
    # before(:context) do
    #   module AccreditedRepresentatives
    #     module V0
    #       class ArbitraryController < ApplicationController
    #         def arbitrary = head :ok
    #       end
    #     end
    #   end

    #   AccreditedRepresentatives::Engine.routes.draw do
    #     namespace :v0, defaults: { format: :json } do
    #       get path_suffix, to: 'arbitrary#arbitrary'
    #     end
    #   end
    # end

    # after(:context) do
    #   # We could have set up our test such that we can unset
    #   # `ArbitraryController` as a const during cleanup. But we'll just leave it
    #   # around and avoid the extra metaprogramming.
    #   Rails.application.reload_routes!
    # end

    subject do
      get path
      response
    end

    describe 'when the representatives_portal_api feature toggle' do
      before do
        expect(Flipper).to(
          receive(:enabled?)
            .with(:representatives_portal_api)
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
