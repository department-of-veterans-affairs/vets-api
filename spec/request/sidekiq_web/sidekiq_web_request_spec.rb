# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sidekiq Web', type: :request do
  routes                  = Sidekiq::WebApplication.instance_variable_get('@routes')
  request_methods         = routes.keys
  build_url_from_pattern  = lambda do |pattern|
    '/sidekiq' + pattern.split('/').map { |path| path[0] == ':' ? '1234' : path }.join('/')
  end

  describe 'authorization' do
    let(:loa1_user) { build(:user, :loa1) }
    let(:loa3_user) { build(:user, :loa3) }

    request_methods.each do |request_method|
      routes[request_method].each do |sidekiq_route|
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
end
