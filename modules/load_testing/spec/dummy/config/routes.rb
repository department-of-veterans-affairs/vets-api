Rails.application.routes.draw do
  mount LoadTesting::Engine => '/load_testing'
end 