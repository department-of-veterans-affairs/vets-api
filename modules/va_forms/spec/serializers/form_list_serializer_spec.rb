# frozen_string_literal: true

require 'rails_helper'

describe VAForms::FormListSerializer, type: :serializer do
  subject { serialize(va_form, serializer_class: described_class) }

  let(:va_form) { build_stubbed(:va_form, :has_been_deleted) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq va_form.row_id.to_s
  end

  it 'includes :form_name' do
    expect(attributes['form_name']).to eq va_form.form_name
  end

  it 'includes :url' do
    expect(attributes['url']).to eq va_form.url
  end

  it 'includes :title' do
    expect(attributes['title']).to eq va_form.title
  end

  it 'includes :first_issued_on' do
    expect(attributes['first_issued_on']).to eq va_form.first_issued_on.to_s
  end

  it 'includes :last_revision_on' do
    expect(attributes['last_revision_on']).to eq va_form.last_revision_on.to_s
  end

  it 'includes :pages' do
    expect(attributes['pages']).to eq va_form.pages
  end

  it 'includes :sha256' do
    expect(attributes['sha256']).to eq va_form.sha256
  end

  it 'includes :last_sha256_change' do
    expect(attributes['last_sha256_change']).to eq va_form.last_sha256_change
  end

  it 'includes :valid_pdf' do
    expect(attributes['valid_pdf']).to eq va_form.valid_pdf
  end

  it 'includes :form_usage' do
    expect(attributes['form_usage']).to eq va_form.form_usage
  end

  it 'includes :form_tool_intro' do
    expect(attributes['form_tool_intro']).to eq va_form.form_tool_intro
  end

  it 'includes :form_tool_url' do
    expect(attributes['form_tool_url']).to eq va_form.form_tool_url
  end

  it 'includes :form_details_url' do
    expect(attributes['form_details_url']).to eq va_form.form_details_url
  end

  it 'includes :form_type' do
    expect(attributes['form_type']).to eq va_form.form_type
  end

  it 'includes :language' do
    expect(attributes['language']).to eq va_form.language
  end

  it 'includes :deleted_at' do
    expect_time_eq(attributes['deleted_at'], va_form.deleted_at)
  end

  it 'includes :related_forms' do
    expect(attributes['related_forms']).to eq va_form.related_forms
  end

  it 'includes :benefit_categories' do
    expect(attributes['benefit_categories']).to eq va_form.benefit_categories
  end

  it 'includes :va_form_administration' do
    expect(attributes['va_form_administration']).to eq va_form.va_form_administration
  end
end
