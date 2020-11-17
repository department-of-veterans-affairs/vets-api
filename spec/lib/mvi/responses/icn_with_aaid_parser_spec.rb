# frozen_string_literal: true

require 'rails_helper'

describe MVI::Responses::ICNWithAAIDParser do
  describe '#without_id_status' do
    context 'when initialized with a valid ICN and Assigning Authority ID' do
      context 'with a valid ID status' do
        it 'returns the icn_with_aaid, trimming off the ID status', :aggregate_failures do
          expect_correct_response_from_without_id_status(
            '12345678901234567^NI^200M^USVHA^P',
            '12345678901234567^NI^200M^USVHA'
          )
        end
      end

      context 'with an invalid ID status' do
        it 'returns nil', :aggregate_failures do
          expect_correct_response_from_without_id_status(
            '12345678901234567^NI^200M^USVHA^PCE',
            nil
          )

          expect_correct_response_from_without_id_status(
            '12345678901234567^NI^200M^USVHA^H',
            nil
          )
        end
      end
    end

    context 'when initialized with nil' do
      it 'returns nil' do
        expect_correct_response_from_without_id_status(
          nil,
          nil
        )
      end
    end
  end
end

def expect_correct_response_from_without_id_status(full_icn, expected_return_value)
  results = MVI::Responses::ICNWithAAIDParser.new(full_icn).without_id_status

  expect(results).to eq expected_return_value
end
