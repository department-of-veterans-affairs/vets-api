# frozen_string_literal: true

require 'rails_helper'
require 'form1010_ezr/service'

RSpec.describe Form1010Ezr::Service do
  describe 'validate_form' do
    context 'when there are no validation errors' do
      it 'returns nil' do
        parsed_form = get_fixture('Fixture goes here')

        expect(described_class.new.validate_form(parsed_form)).to eq(nil)
      end
    end

    context 'when there are validation errors' do
      it 'logs an error messages and raises a StandardError' do
        allow(Rails.logger).to receive(:error)

        expect do
          described_class.new.validate_form({})
        end.to raise_error(StandardError, '1010EZR form validation failed. Form does not match schema.')
        expect(Rails.logger).to have_received(:error).with(
          '1010EZR form validation failed. Form does not match schema.'
        )
      end
    end
  end
end
