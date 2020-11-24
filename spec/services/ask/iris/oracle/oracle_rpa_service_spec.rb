# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ask::Iris::Oracle::OracleRPAService' do
  describe 'should return a confirmation number' do
    it('should return confirmation number') do

      form_data = get_fixture('ask/maximal').to_json

      form = Ask::Iris::Oracle::OracleForm.new form_data

      expect(Ask::Iris::OracleRPAService.submit_form(form)).to match(/#[0-9-]*/)
    end
  end
end
