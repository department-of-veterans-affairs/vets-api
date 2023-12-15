# frozen_string_literal: true

class PreferredNameValidator < ActiveModel::Validator
  def validate(record)
    unless record =~ /^[a-zA-ZÀ-ÖØ-öø-ÿ\-áéíóúäëïöüâêîôûãñõ]+$/
      record.errors[:base] << "must only contain alpha, -, acute, grave, diaresis, circumflex, tilde"
    end
  end
end