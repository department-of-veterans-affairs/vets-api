# frozen_string_literal: true

module VAForms
  class Form < ApplicationRecord
    include PgSearch::Model
    pg_search_scope :search,
                    against: %i[title form_name],
                    using: { tsearch: { normalization: 4, any_word: true, prefix: true, dictionary: 'english' },
                             trigram: {
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

    def self.return_all
      Form.all.sort_by(&:updated_at)
    end

    def self.search_by_form_number(search_term)
      search_term.sub! '-', '%'
      query = search_term.split.join('%').upcase
      Form.where('upper(form_name) LIKE ?', "%#{query}%")
    end

    private

    def set_revision
      self.last_revision_on = first_issued_on if last_revision_on.blank?
    end
  end
end
