# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sidekiq Web', type: :request do
  routes_by_method        = Sidekiq::WebApplication.instance_variable_get('@routes')
  routes                  = routes_by_method.values.flatten
  build_url_from_pattern  = lambda do |pattern|
    '/sidekiq' + pattern.split('/').map { |path| path[0] == ':' ? '1234' : path }.join('/')
  end

  describe 'authorization' do
    let(:loa1_user) { build(:user, :loa1) }
    let(:loa3_user) { build(:user, :loa3) }

    it 'protects all routes' do
      # The test suite relies on Sidekiq::WebApplication's internals and can break on updates to their library.
      # If this test fails, it's likely that an update was made to Sidekiq::WebApplication.
      #
      # To relove this test failure either:
      #
      # - Update the number of routes provided by Sidekiq::WebApplication (in the case routes were added/removed)
      # - Update the reference of `routes` (in the case the variable changes location or name)
      expect(routes.length).to eq(69)
    end

    routes.each do |sidekiq_route|
      request_method  = sidekiq_route.request_method.downcase
      path            = build_url_from_pattern.call(sidekiq_route.pattern)

      context "#{request_method} #{sidekiq_route.pattern}" do
        context 'when unauthenticated' do
          it 'renders 403' do
            send(request_method, path)
            expect(response.status).to eq(403)
          end
        end

        context 'when authenticated' do
          context 'with loa1' do
            before do
              sign_in_as(loa1_user)
            end

            it 'renders 403' do
              send(request_method, path)
              expect(response.status).to eq(403)
            end
          end

          context 'with loa3' do
            before do
              sign_in_as(loa3_user)
            end

            context 'and not in admin list' do
              it 'renders 403' do
                send(request_method, path)
                expect(response.status).to eq(403)
              end
            end

            context 'and in admin list' do
              before do
                sign_in_as(loa3_user)
                # TODO: Add user to config list
              end

              xit 'executes the request' do
                # (?) Expect sidekiq web to recieve the route call
                # (?) Expect response status not to be 403 (3**, 400, 5**, etc.)
              end
            end
          end
        end
      end
    end
  end
end
