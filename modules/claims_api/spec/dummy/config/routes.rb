Rails.application.routes.draw do
  mount ClaimsApi::Engine => '/'
end