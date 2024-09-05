# frozen_string_literal: true

require_relative '../support/helpers/rails_helper'
require 'mobile/v0/exceptions/custom_errors'

describe Mobile::V0::Exceptions::CustomErrors do
  let(:error) do
    described_class.new(
      title: 'Custom error title',
      body: 'Custom error body. \n This explains to the user the details of the ongoing issue.',
      source: 'VAOS',
      telephone: '999-999-9999',
      refreshable: true
    )
  end

  context 'when error is raised'
  it 'outputs expected fields' do
    expect { raise error }.to raise_error(described_class) { |e|
      expect(e.title).to equal('Custom error title')
      expect(e.body).to equal('Custom error body. \n This explains to the user the details of the ongoing issue.')
      expect(e.source).to equal('VAOS')
      expect(e.telephone).to equal('999-999-9999')
      expect(e.refreshable).to equal(true)
    }
  end
end
