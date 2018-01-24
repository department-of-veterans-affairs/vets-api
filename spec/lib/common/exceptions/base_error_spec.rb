# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::BaseError do
  subject { described_class.new }
  it 'raises an error when errors is invoked' do
    expect { subject.errors }
      .to raise_error(NotImplementedError, 'Subclass of Error must implement errors method')
  end
end
