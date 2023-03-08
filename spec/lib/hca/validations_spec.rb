# frozen_string_literal: true

require_relative '../../../config/environment'
require 'hca/validations'

frozen_time = '2017-01-04 03:00:00 EDT'
frozen_date = Time.zone.parse(frozen_time).to_date

describe HCA::Validations, run_at: frozen_time do
  test_method(
    described_class,
    'date_of_birth',
    [
      ['', ''],
      [1234, ''],
      ['3000-01-01', ''],
      ['1974-12-01', '12/01/1974']
    ]
  )

  test_method(
    described_class,
    'discharge_date',
    [
      ['', ''],
      [1234, ''],
      ['3000-01-01', '01/01/3000'],
      ['1974-12-01', '12/01/1974']
    ]
  )

  test_method(
    described_class,
    'valid_discharge_date?',
    [
      ['', false],
      [1234, false],
      ['3000-01-01', false],
      ['1974-12-01', true],
      [(frozen_date + 60.days).strftime('%Y-%m-%d'), true],
      [(frozen_date + 181.days).strftime('%Y-%m-%d'), false]
    ]
  )

  test_method(
    described_class,
    'validate_string',
    [
      [{ nullable: true, data: '' }, nil],
      [{ data: '' }, ''],
      [{ data: 1 }, ''],
      [{ data: 'dog' }, 'Dog'],
      [{ data: 'dog', count: 2 }, 'Do'],
      [{ data: 'DOG' }, 'DOG'],
      [{ data: 'dog', count: 10 }, 'Dog']
    ]
  )

  test_method(
    described_class,
    'validate_name',
    [
      [{ data: 'foo' }, 'FOO'],
      [{ data: 'foo', count: 2 }, 'FO'],
      [{ data: 1 }, '']
    ]
  )

  test_method(
    described_class,
    'validate_ssn',
    [
      ['', ''],
      [['1'], ''],
      [111_111_111, ''],
      ['000111111', ''],
      %w[210438765 210438765],
      %w[210-43-8765 210438765],
      ['1112233334444', '']
    ]
  )
end
