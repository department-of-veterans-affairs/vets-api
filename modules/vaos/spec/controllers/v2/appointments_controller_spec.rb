# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::AppointmentsController, type: :request do
  describe '#start_date' do
    context 'with an invalid date' do
      it 'throws an InvalidFieldValue exception' do
        subject.params = { start: 'not a date', end: '2022-09-21T00:00:00+00:00' }

        expect do
          subject.send(:start_date)
        end.to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#end_date' do
    context 'with an invalid date' do
      it 'throws an InvalidFieldValue exception' do
        subject.params = { end: 'not a date', start: '2022-09-21T00:00:00+00:00' }

        expect do
          subject.send(:end_date)
        end.to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end
end
