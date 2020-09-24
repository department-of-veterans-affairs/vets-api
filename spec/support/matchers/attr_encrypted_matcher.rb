# frozen_string_literal: true

RSpec::Matchers.define :encrypt_attr do |attribute|
  encrypted_attribute = ('encrypted_' + attribute.to_s)

  match do |model|
    model.respond_to?(attribute) &&
      model.respond_to?(encrypted_attribute.intern) &&
      model.class.column_names.include?(encrypted_attribute)
  end

  failure_message do |model|
    if !model.class.column_names.include?(encrypted_attribute)
      "#{encrypted_attribute} must be a column on #{model.class} for encryption to work"
    else
      "#{attribute} should use attr_encrypted on #{model.class}"
    end
  end

  failure_message_when_negated do |model|
    if !model.class.column_names.include?(encrypted_attribute)
      "#{encrypted_attribute} shouldn't be a column on #{model.class}"
    else
      "#{attribute} should not use attr_encrypted on #{model.class}"
    end
  end
end
