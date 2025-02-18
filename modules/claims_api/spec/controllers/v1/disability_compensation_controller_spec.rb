# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::V1::Forms::DisabilityCompensationController, type: :controller do
  describe '#format_526_errors' do
    it 'formats errors correctly' do
      error = [
        {
          key: 'header.va_eauth_birlsfilenumber.Invalid',
          severity: 'ERROR',
          text: 'Size must be between 8 and 9'
        }
      ]

      formatted_error = subject.send(:format_526_errors, error)

      expect(formatted_error).to contain_exactly({ status: 422, detail: "#{error[0][:key]}, #{error[0][:text]}",
                                                   source: error[0][:key] })
    end
  end
end
