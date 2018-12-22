# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

####
# Thanks for all the help SimpleCov https://github.com/colszowka/simplecov-html
# initial version of test pulled into Coverband from Simplecov 12/17/2018
####
describe Coverband::Utils::LinesClassifier do
  describe '#classify' do
    def subject
      Coverband::Utils::LinesClassifier.new
    end

    describe 'relevant lines' do
      it 'determines code as relevant' do
        classified_lines = subject.classify [
          'module Foo',
          '  class Baz',
          '    def Bar',
          "      puts 'hi'",
          '    end',
          '  end',
          'end'
        ]

        assert_equal 7, classified_lines.length
        assert(classified_lines.all? { |line| line == Coverband::Utils::LinesClassifier::RELEVANT })
      end

      it 'determines invalid UTF-8 byte sequences as relevant' do
        classified_lines = subject.classify [
          "bytes = \"\xF1t\xEBrn\xE2ti\xF4n\xE0liz\xE6ti\xF8n\""
        ]

        assert_equal 1, classified_lines.length
        assert(classified_lines.all? { |line| line == Coverband::Utils::LinesClassifier::RELEVANT })
      end
    end

    describe 'not-relevant lines' do
      it 'determines whitespace is not-relevant' do
        classified_lines = subject.classify [
          '',
          '   ',
          "\t\t"
        ]

        assert_equal 3, classified_lines.length
        assert(classified_lines.all? { |line| line == Coverband::Utils::LinesClassifier::NOT_RELEVANT })
      end

      describe 'comments' do
        it 'determines comments are not-relevant' do
          classified_lines = subject.classify [
            '#Comment',
            ' # Leading space comment',
            "\t# Leading tab comment"
          ]

          assert_equal 3, classified_lines.length
          assert(classified_lines.all? { |line| line == Coverband::Utils::LinesClassifier::NOT_RELEVANT })
        end

        it "doesn't mistake interpolation as a comment" do
          classified_lines = subject.classify [
            'puts "#{var}"'
          ]

          assert_equal 1, classified_lines.length
          assert(classified_lines.all? { |line| line == Coverband::Utils::LinesClassifier::RELEVANT })
        end
      end

      describe ':nocov: blocks' do
        it 'determines :nocov: blocks are not-relevant' do
          classified_lines = subject.classify [
            '# :nocov:',
            'def hi',
            'end',
            '# :nocov:'
          ]

          assert_equal 4, classified_lines.length
          assert(classified_lines.all? { |line| line == Coverband::Utils::LinesClassifier::NOT_RELEVANT })
        end

        it 'determines all lines after a non-closing :nocov: as not-relevant' do
          classified_lines = subject.classify [
            '# :nocov:',
            "puts 'Not relevant'",
            '# :nocov:',
            "puts 'Relevant again'",
            "puts 'Still relevant'",
            '# :nocov:',
            "puts 'Not relevant till the end'",
            "puts 'Ditto'"
          ]

          assert_equal 8, classified_lines.length

          assert(classified_lines[0..2].all? { |line| line == Coverband::Utils::LinesClassifier::NOT_RELEVANT })
          assert(classified_lines[3..4].all? { |line| line == Coverband::Utils::LinesClassifier::RELEVANT })
          assert(classified_lines[5..7].all? { |line| line == Coverband::Utils::LinesClassifier::NOT_RELEVANT })
        end
      end
    end
  end
end
