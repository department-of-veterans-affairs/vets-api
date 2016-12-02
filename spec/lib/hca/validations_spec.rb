# frozen_string_literal: true
require 'rails_helper'
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
end
