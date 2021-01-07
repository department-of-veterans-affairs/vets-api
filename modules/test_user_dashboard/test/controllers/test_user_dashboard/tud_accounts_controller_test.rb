# frozen_string_literal: true

require 'test_helper'

module TestUserDashboard
  class TudAccountsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    test 'should get index' do
      get tud_accounts_index_url
      assert_response :success
    end
  end
end
