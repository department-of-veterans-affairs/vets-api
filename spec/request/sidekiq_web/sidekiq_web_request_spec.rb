# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sidekiq Web', type: :request do
  routes                  = Sidekiq::WebApplication.instance_variable_get('@routes')
  request_methods         = Sidekiq::WebApplication.instance_variable_get('@routes').keys
  build_url_from_pattern  = lambda do |pattern|
    '/sidekiq' + pattern.split('/').map { |path| path[0] == ':' ? '1234' : path }.join('/')
  end

  describe 'authentication' do
  end

  describe 'authorization' do
    request_methods.each do |request_method|
      routes[request_method].each do |sidekiq_route|
        request_method  = sidekiq_route.request_method.downcase
        path            = build_url_from_pattern.call(sidekiq_route.pattern)

        context "#{request_method} #{sidekiq_route.pattern}" do
          it 'requires login' do
            send(request_method, path)
            expect(response.status).to eq(403)
          end

          # xit 'requires loa3' {}
          # xit 'requires user to exist in admin list' {}
        end
      end
    end
  end
end
