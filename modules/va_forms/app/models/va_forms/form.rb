# frozen_string_literal: true

module VAForms
  class Form < ApplicationRecord
    include PgSearch::Model
    pg_search_scope :new_search,
                    against: %i[title form_name],
                    using: { tsearch: { prefix: true, dictionary: 'english' }, trigram:  {
                      word_similarity: true
                    } }
    has_paper_trail only: ['sha256']

    validates :title, presence: true
    validates :form_name, presence: true, uniqueness: true
    validates :row_id, uniqueness: true
    validates :url, presence: true
    validates :sha256, presence: true
    validates :valid_pdf, inclusion: { in: [true, false] }

    before_save :set_revision

    def self.search(search_term)
      query = Form.all
      if search_term.present?
        search_term.strip!
        terms = search_term.split.map { |term| "%#{term}%" }
        query = query.where('form_name ilike ANY ( array[?] ) OR title ilike ANY ( array[?] )', terms, terms)
      end
      query
    end

    private

    def set_revision
      self.last_revision_on = first_issued_on if last_revision_on.blank?
    end
  end
end
