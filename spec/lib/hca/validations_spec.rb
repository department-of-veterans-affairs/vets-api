# frozen_string_literal: true
require 'spec_helper'
require 'hca/validations'

describe HCA::Validations do
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
      %w(210438765 210438765),
      ['210-43-8765', '210438765'],
      ['1112233334444', '']
    ]
  )
end
