# frozen_string_literal: false

require 'rails_helper'
require 'va_forms/regex_helper'

RSpec.describe VAForms::RegexHelper

context 'When a form number is passed' do
  let(:helper) { VAForms::RegexHelper.new }

  it 'checked for VA and Form prefix and removed' do
    result = helper.scrub_query('VA Form 9')
    expect(result).to eq('9')
  end

  it 'checks for 1010 no dash and adds dash' do
    result = helper.scrub_query('1010')
    expect(result).to eq('10-10')
  end

  it 'checks for 10 10 no dash and adds dash' do
    result = helper.scrub_query('10 10')
    expect(result).to eq('10-10')
  end

  it 'checks for 10 10ez no dash and adds dash  retain letters' do
    result = helper.scrub_query('10 10ez')
    expect(result).to eq('10-10ez')
  end

  it 'checked for GSA prefix and insert wildcard' do
    result = helper.scrub_query('GSA1010')
    expect(result).to eq('GSA%1010')
  end

  it 'adds a wildcard to 21P' do
    result = helper.scrub_query('21P1000')
    expect(result).to eq('21P%1000')
  end

  it 'corrects a DDD form' do
    result = helper.scrub_query('220810')
    expect(result).to eq('22%0810')
  end
end
