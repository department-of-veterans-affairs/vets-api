Rails.application.routes.draw do

  mount OpenidAuth::Engine => "/openid_auth"
end
