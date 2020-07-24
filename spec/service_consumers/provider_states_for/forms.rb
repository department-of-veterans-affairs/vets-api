# frozen_string_literal: true

Pact.provider_states_for 'Forms' do
  provider_state 'list forms' do
    set_up do
      return if Rails.env.production?

      VaForms::Form.first || FactoryBot.create(:va_form)
    end
  end

  provider_state 'show form' do
    set_up do
      return if Rails.env.production?

      VaForms::Form.first || FactoryBot.create(:va_form)
    end
  end
end
