# frozen_string_literal: true

DebtsApi::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    resources :financial_status_reports, only: %i[create] do
      collection do
        get :download_pdf
        get :submissions
      end
    end

    resources :digital_disputes, only: %i[create]

    get 'financial_status_reports/rehydrate_submission/:submission_id', to: 'financial_status_reports#rehydrate'
    post 'financial_status_reports/transform_and_submit', to: 'financial_status_reports#transform_and_submit'

    post 'calculate_total_assets', to: 'financial_status_reports_calculations#total_assets'
    post 'calculate_monthly_expenses', to: 'financial_status_reports_calculations#monthly_expenses'
    post 'calculate_all_expenses', to: 'financial_status_reports_calculations#all_expenses'
    post 'calculate_monthly_income', to: 'financial_status_reports_calculations#monthly_income'
    post 'combine_one_debt_letter_pdf', to: 'one_debt_letters#combine_pdf'
  end
end
