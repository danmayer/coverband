# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

describe Coverband::Utils::LinesClassifier do
  describe '#classify' do
    describe 'relevant lines' do
      def subject
        Coverband::Utils::LinesClassifier.new
      end

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

        assert_equal classified_lines.length, 7
        assert(classified_lines.all? { |line| line == Coverband::Utils::LinesClassifier::RELEVANT })
      end

      it 'determines invalid UTF-8 byte sequences as relevant' do
        classified_lines = subject.classify [
          "bytes = \"\xF1t\xEBrn\xE2ti\xF4n\xE0liz\xE6ti\xF8n\""
        ]

        assert_equal classified_lines.length, 1
        assert(classified_lines.all? { |line| line == Coverband::Utils::LinesClassifier::RELEVANT })
      end
    end
  end
end
