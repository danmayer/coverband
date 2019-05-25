# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

describe 'results' do
  describe 'with a (mocked) Coverage.result' do
    let(:eager_lines) { [nil, 1, 1, 0, nil, nil, 1, 0, nil, nil] }
    let(:run_lines) { [nil, nil, nil, 1, nil, nil, nil,nil, nil, nil] }
    let(:original_result) do
      {
        Coverband::EAGER_TYPE => {source_fixture('app/models/user.rb') => eager_lines},
        Coverband::RUNTIME_TYPE => {source_fixture('app/models/user.rb') => run_lines},
        Coverband::MERGED_TYPE => {source_fixture('app/models/user.rb') => eager_lines},
      }
    end

    describe 'a runtime relevant lines is supported' do
      subject { Coverband::Utils::Results.new(original_result) }
      let(:source_file) { Coverband::Utils::SourceFile.new(source_fixture('app/models/user.rb'), run_lines) }

      it 'has correct runtime relevant coverage' do
        assert_equal 50.0, subject.runtime_relevant_coverage(source_file)
      end
    end
  end
end
