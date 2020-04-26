# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

describe "results" do
  describe "with a (mocked) Coverage.result" do
    let(:source_file) { Coverband::Utils::SourceFile.new(source_fixture("app/models/user.rb"), run_lines) }
    let(:eager_lines) { [nil, 1, 1, 0, nil, nil, 1, 0, nil, nil] }
    let(:run_lines) { [nil, nil, nil, 1, nil, nil, nil, nil, nil, nil] }
    let(:original_result) do
      orig = {
        Coverband::MERGED_TYPE => {source_fixture("app/models/user.rb") => eager_lines}
      }
      orig[Coverband::EAGER_TYPE] = {source_fixture("app/models/user.rb") => eager_lines} if eager_lines
      orig[Coverband::RUNTIME_TYPE] = {source_fixture("app/models/user.rb") => run_lines} if run_lines
      orig
    end
    subject { Coverband::Utils::Results.new(original_result) }

    describe "runtime relevant lines is supported" do
      it "has correct runtime relevant coverage" do
        assert_equal 50.0, subject.runtime_relevant_coverage(source_file)
      end

      it "has correct runtime relevant lines" do
        assert_equal 2, subject.runtime_relavent_lines(source_file)
      end
    end

    describe "runtime relevant lines when no runtime coverage exists" do
      let(:run_lines) { nil }

      it "has correct runtime relevant lines" do
        assert_equal 0.0, subject.runtime_relevant_coverage(source_file)
      end

      it "has correct runtime relevant lines" do
        assert_equal 2, subject.runtime_relavent_lines(source_file)
      end
    end

    describe "runtime relevant lines when no eager coverage exists" do
      let(:eager_lines) { nil }

      it "has correct runtime relevant lines" do
        assert_equal 100.0, subject.runtime_relevant_coverage(source_file)
      end

      it "has correct runtime relevant lines" do
        assert_equal 1, subject.runtime_relavent_lines(source_file)
      end
    end
  end
end
