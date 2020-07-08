# frozen_string_literal: true

module MVI
  module Models
    class MviUserAttributes
      include ActiveModel::Validations
      include Virtus.model(nullify_blank: true)

      attribute :first_name, String
      attribute :middle_name, String
      attribute :last_name, String
      attribute :birth_date, String
      attribute :ssn, String
      attribute :gender, String

      validates :first_name, :last_name, :birth_date, :ssn, presence: true
      validates :gender,
                inclusion: { in: %w[M F] },
                unless: proc { |model| model.gender.blank? }

      def ssn=(new_ssn)
        super(new_ssn&.gsub(/\D/, ''))
      end
    end
  end
end
