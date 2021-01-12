# frozen_string_literal: true

Rails.application.routes.draw do
  mount TestUserDashboard::Engine => '/test_user_dashboard'
end
