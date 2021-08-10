# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    module PdfGenerator
      #
      # Object for defining the basic properties of the PDF file
      # like the Title, Language, Author, Creator, Publisher etc
      #
      class Properties
        ##
        # A method to create an instance of {HealthQuest::QuestionnaireManager::PdfGenerator::Properties}
        #
        # @return [HealthQuest::QuestionnaireManager::PdfGenerator::Properties]
        #
        def self.build
          new
        end

        ##
        # A method to return the documents properties as key/value pairs
        #
        # @return [Hash] the key value pairs of properties for the generated PDF file
        #
        def info
          {
            Lang: language,
            Title: title,
            Author: author,
            Subject: subject,
            Keywords: keywords,
            Creator: creator,
            Producer: producer,
            CreationDate: creation_date
          }
        end

        ##
        # A method for returning the main title for the generated PDF file
        #
        # @return [String] the contents of the title string
        #
        def title
          'Primary Care Questionnaire'
        end

        ##
        # A method for returning the language property for the generated PDF file
        #
        # @return [String] the contents of the language string
        #
        def language
          'en-us'
        end

        ##
        # A method for returning the author property for the generated PDF file
        #
        # @return [String] the contents of the author string
        #
        def author
          'Department of Veterans Affairs'
        end

        ##
        # A method for returning the subject property for the generated PDF file
        #
        # @return [String] the contents of the subject string
        #
        def subject
          'Primary Care Questionnaire'
        end

        ##
        # A method for returning the keywords property for the generated PDF file
        #
        # @return [String] the contents of the keywords string
        #
        def keywords
          'health questionnaires pre-visit'
        end

        ##
        # A method for returning the creator property for the generated PDF file
        #
        # @return [String] the contents of the creator string
        #
        def creator
          'va.gov'
        end

        ##
        # A method for returning the producer property for the generated PDF file
        #
        # @return [String] the contents of the producer string
        #
        def producer
          'va.gov'
        end

        ##
        # A method for returning the creation_date property for the generated PDF file
        #
        # @return [String] the contents of the creation_date string
        #
        def creation_date
          Time.zone.today.to_s
        end

        ##
        # A method for returning the page_size property for the generated PDF file
        #
        # @return [String] the contents of the page_size string
        #
        def page_size
          'A4'
        end

        ##
        # A method for returning the page_layout property for the generated PDF file
        #
        # @return [Symbol] the contents of the page_layout symbol
        #
        def page_layout
          :portrait
        end

        ##
        # A method for returning the margin property for the generated PDF file
        #
        # @return [Integer] the contents of the margin value
        #
        def margin
          0
        end
      end
    end
  end
end
