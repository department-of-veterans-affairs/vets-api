# frozen_string_literal: true

module VAForms
  class Form < ApplicationRecord
    include PgSearch::Model
    pg_search_scope :search,
                    against: { tags: 'A',
                               title: 'B',
                               form_name: 'C' },
                    using: { tsearch: { normalization: 4, any_word: true, prefix: true, dictionary: 'english' },
                             trigram: {
                               word_similarity: true
                             } },
                    order_within_rank: 'va_forms_forms.ranking ASC, va_forms_forms.language ASC'

    has_paper_trail only: ['sha256']

    validates :title, presence: true
    validates :form_name, presence: true
    validates :row_id, uniqueness: true
    validates :url, presence: true
    validates :sha256, presence: true
    validates :valid_pdf, inclusion: { in: [true, false] }

    before_save :set_revision

    def self.return_all
      Form.all.sort_by(&:updated_at)
    end

    def self.search_by_form_number(search_term)
      Form.where('upper(form_name) LIKE ?', "%#{search_term.upcase}%").order(form_name: :asc, language: :asc)
    end

    def self.old_search(search_term: nil)
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
