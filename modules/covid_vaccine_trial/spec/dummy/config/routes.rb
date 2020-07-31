Rails.application.routes.draw do
  mount CovidVaccineTrial::Engine => "/covid_vaccine_trial"
end
