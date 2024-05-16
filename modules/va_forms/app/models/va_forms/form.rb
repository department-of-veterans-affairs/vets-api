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

    validates :title, presence: true
    validates :form_name, presence: true
    validates :row_id, uniqueness: true
    validates :url, presence: true
    validates :valid_pdf, inclusion: { in: [true, false] }

    before_save :set_revision
    before_save :set_sha256_history

    FORM_BASE_URL = 'https://www.va.gov'

    def self.return_all
      Form.all.sort_by(&:updated_at)
    end

    def self.search_by_form_number(search_term)
      Form.where('upper(form_name) LIKE ?', "%#{search_term.upcase}%")
          .order(form_name: :asc, deleted_at: :desc, language: :asc, title: :asc)
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

    def self.normalized_form_url(url)
      url = url.starts_with?('http') ? url.gsub('http:', 'https:') : expanded_va_url(url)
      Addressable::URI.parse(url).normalize.to_s
    end

    def self.expanded_va_url(url)
      raise ArgumentError, 'url must start with ./va or ./medical' unless url.starts_with?('./va', './medical')

      "#{FORM_BASE_URL}/vaforms/#{url.gsub('./', '')}" if url.starts_with?('./va') || url.starts_with?('./medical')
    end

    private

    def set_revision
      self.last_revision_on = first_issued_on if last_revision_on.blank?
    end

    def set_sha256_history
      if sha256.present? && sha256_changed?
        self.last_sha256_change = Time.zone.today

        current_history = change_history&.dig('versions')
        new_history = { sha256:, revision_on: last_sha256_change.strftime('%Y-%m-%d') }

        if current_history.present? && current_history.is_a?(Array)
          change_history['versions'] << new_history
        else
          self.change_history = { versions: [new_history] }
        end
      end
    end
  end
end
