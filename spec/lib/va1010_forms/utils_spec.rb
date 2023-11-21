# frozen_string_literal: true

require 'rails_helper'
require 'va1010_forms/utils'

RSpec.describe VA1010Forms::Utils do
  describe '#override_parsed_form' do
    context 'when the form contains a Mexican province as an address state' do
      it 'returns the correct corresponding province abbreviation' do
        form_with_mexican_province = get_fixture('form1010_ezr/valid_form_with_mexican_province')
        test_class =
          Class.new do
            include VA1010Forms::Utils
          end
        overridden_form = test_class.new.override_parsed_form(form_with_mexican_province)

        expect(overridden_form['veteranAddress']['state']).to eq('CHIH.')
        expect(overridden_form['veteranHomeAddress']['state']).to eq('CHIH.')
      end
    end
  end
end
