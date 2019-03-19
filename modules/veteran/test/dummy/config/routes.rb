# frozen_string_literal: true

Rails.application.routes.draw do
  mount Veteran::Engine => '/veteran'
end
