# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

describe "results" do
  describe "with a stored Coverband report" do
    let(:source_file) { Coverband::Utils::SourceFile.new(source_fixture("app/models/user.rb"), record(source_lines)) }
    let(:eager_lines) { [nil, 1, 1, 0, nil, nil, 1, 0, nil, nil] }
    let(:source_lines) { [nil, nil, nil, 1, nil, nil, nil, nil, nil, nil] }
    let(:run_lines) { [nil, nil, nil, 1, nil, nil, nil, nil, nil, nil] }
    let(:missing_run_coverage_file) { false }
    let(:original_result) do
      orig = {
        Coverband::MERGED_TYPE => {source_fixture("app/models/user.rb") => record(eager_lines)}
      }
      orig[Coverband::EAGER_TYPE] = {source_fixture("app/models/user.rb") => record(eager_lines)} if eager_lines
      orig[Coverband::RUNTIME_TYPE] = {source_fixture("app/models/user.rb") => record(run_lines)} if run_lines
      orig[Coverband::RUNTIME_TYPE] = {"random.rb" => record([nil, 1, nil])} if missing_run_coverage_file
      orig
    end
    subject { Coverband::Utils::Results.new(original_result) }

    def record(lines)
      {"data" => lines}
    end

    describe "runtime relevant lines is supported" do
      it "has correct runtime relevant coverage" do
        assert_equal 50.0, subject.runtime_relevant_coverage(source_file)
      end

      it "has correct runtime relevant lines" do
        assert_equal 2, subject.runtime_relevant_lines(source_file)
      end
    end

    describe "delegating to the merged results" do
      it "answers respond_to? including private methods" do
        assert subject.respond_to?(:source_files, true)
        refute subject.respond_to?(:not_a_results_method, true)
      end
    end

    describe "runtime relevant lines when no runtime coverage file matches" do
      let(:run_lines) { nil }

      it "has correct runtime relevant coverage" do
        assert_equal 0, subject.runtime_relevant_coverage(source_file)
      end

      it "has correct runtime relevant lines" do
        assert_equal 0, subject.runtime_relevant_lines(source_file)
      end
    end

    describe "runtime relevant lines when no runtime coverage exists" do
      let(:run_lines) { nil }
      let(:missing_run_coverage_file) { true }

      it "has correct runtime relevant coverage" do
        assert_equal 0.0, subject.runtime_relevant_coverage(source_file)
      end

      it "has correct runtime relevant lines" do
        assert_equal 0, subject.runtime_relevant_lines(source_file)
      end
    end

    describe "runtime relevant lines when load-time lines are also hit at runtime" do
      # e.g. a lazily loading process runs the class body after the switch to runtime
      let(:run_lines) { [nil, 1, 1, 1, nil, nil, 1, 0, nil, nil] }

      it "only counts runtime hits on runtime relevant lines" do
        assert_equal 50.0, subject.runtime_relevant_coverage(source_file)
      end

      it "has correct runtime relevant lines" do
        assert_equal 2, subject.runtime_relevant_lines(source_file)
      end
    end

    describe "runtime relevant lines when the file was never eager loaded" do
      let(:eager_lines) { nil }
      let(:original_result) do
        {
          Coverband::MERGED_TYPE => {source_fixture("app/models/user.rb") => record(run_lines)},
          Coverband::EAGER_TYPE => {source_fixture("app/models/user.rb") => {"data" => [], "never_loaded" => true}},
          Coverband::RUNTIME_TYPE => {source_fixture("app/models/user.rb") => record(run_lines)}
        }
      end
      let(:run_lines) { [nil, 1, 1, 1, nil, nil, 1, 0, nil, nil] }

      it "uses the runtime file's relevant lines" do
        assert_equal 80.0, subject.runtime_relevant_coverage(source_file)
      end

      it "has correct runtime relevant lines" do
        assert_equal 5, subject.runtime_relevant_lines(source_file)
      end
    end

    # Checks every combination of eager/runtime hits on the fixture's relevant lines
    # against the invariants users read off the report (see README "Interpreting results").
    describe "runtime relevant coverage invariants" do
      let(:relevant_indexes) { [1, 2, 3, 6, 7] }

      def coverage_for(hits)
        lines = Array.new(10)
        relevant_indexes.each_with_index { |index, i| lines[index] = hits[i] }
        lines
      end

      def results_for(eager_record, run_hits)
        file = source_fixture("app/models/user.rb")
        Coverband::Utils::Results.new(
          Coverband::MERGED_TYPE => {file => record(coverage_for(run_hits))},
          Coverband::EAGER_TYPE => {file => eager_record},
          Coverband::RUNTIME_TYPE => {file => record(coverage_for(run_hits))}
        )
      end

      it "holds for every eager and runtime combination" do
        hit_patterns = [0, 1].repeated_permutation(relevant_indexes.size).to_a
        eager_records = hit_patterns.map { |hits| [record(coverage_for(hits)), hits] }
        eager_records << [{"data" => [], "never_loaded" => true}, [0] * relevant_indexes.size]

        eager_records.each do |eager_record, eager_hits|
          hit_patterns.each do |run_hits|
            results = results_for(eager_record, run_hits)
            runtime_relevant = relevant_indexes.each_index.reject { |i| eager_hits[i] == 1 }
            runtime_covered = runtime_relevant.count { |i| run_hits[i] == 1 }
            message = "eager=#{eager_record.inspect} runtime=#{run_hits.inspect}"

            assert_equal runtime_relevant.size, results.runtime_relevant_lines(source_file), message
            assert_operator results.runtime_relevant_lines(source_file), :<=, relevant_indexes.size, message

            percent = results.runtime_relevant_coverage(source_file)
            assert_includes 0.0..100.0, percent, message
            expected = runtime_relevant.empty? ? 0.0 : (runtime_covered * 100.0 / runtime_relevant.size).round(2)
            assert_equal expected, percent, message
            assert_equal(runtime_covered == runtime_relevant.size && runtime_relevant.any?, percent >= 100.0, message)
          end
        end
      end
    end

    describe "runtime relevant lines when no eager coverage exists" do
      let(:eager_lines) { nil }

      it "has correct runtime relevant lines" do
        assert_equal 100.0, subject.runtime_relevant_coverage(source_file)
      end

      it "has correct runtime relevant lines" do
        assert_equal 1, subject.runtime_relevant_lines(source_file)
      end
    end
  end
end
