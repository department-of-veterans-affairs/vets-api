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

  describe '#validate_ref_id' do
    context 'with matching icns with aaid' do
      it 'validates referral id' do
        expect(subject.send(:validate_ref_id, '1012845331V153043', '1012845331V153043^NI^200M^USVHA')).to equal(true)
      end
    end

    context 'with matching icns' do
      it 'validates referral id' do
        expect(subject.send(:validate_ref_id, '1012845331V153043', '1012845331V153043')).to equal(true)
      end
    end

    context 'with non-matching icns' do
      it 'fails validation' do
        expect(subject.send(:validate_ref_id, '1029483756V301856', '1012845331V153043^NI^200M^USVHA')).to equal(false)
      end
    end

    context 'invalid icns' do
      it 'fails validation' do
        expect(subject.send(:validate_ref_id, '123456ABCD', '101284^78ABC')).to equal(false)
      end
    end

    context 'missing icns' do
      it 'fails validation' do
        expect(subject.send(:validate_ref_id, nil, nil)).to equal(false)
      end
    end
  end
end
