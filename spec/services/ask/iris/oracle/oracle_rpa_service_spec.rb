# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ask::Iris::Oracle::OracleRPAService' do
  describe 'should return a confirmation number' do
    it('returns confirmation number') do
      form_data = get_fixture('ask/maximal')

      form = Ask::Iris::Oracle::OracleForm.new form_data

      VCR.use_cassette('oracle_rpa/success') do
        expect(Ask::Iris::OracleRPAService.submit_form(form)).to match(/#[0-9-]*/)
      end
    end
  end
end
