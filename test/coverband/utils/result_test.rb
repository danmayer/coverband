# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

####
# Thanks for all the help SimpleCov https://github.com/colszowka/simplecov-html
# initial version of test pulled into Coverband from Simplecov 12/19/2018
####
describe "result" do
  describe "with a (mocked) Coverage.result" do
    let(:original_result) do
      {
        source_fixture("sample.rb") => [nil, 1, 1, 1, nil, nil, 1, 1, nil, nil],
        source_fixture("app/models/user.rb") => [nil, 1, 1, 1, nil, nil, 1, 0, nil, nil],
        source_fixture("app/controllers/sample_controller.rb") => [nil, 1, 1, 1, nil, nil, 1, 0, nil, nil]
      }
    end

    describe "a simple cov result initialized from that" do
      subject { Coverband::Utils::Result.new(original_result) }

      it "has 3 filenames" do
        assert_equal 3, subject.filenames.count
      end

      it "has 3 source files" do
        assert_equal 3, subject.source_files.count
        subject.source_files.each do |source_file|
          assert source_file.is_a?(Coverband::Utils::SourceFile)
        end
      end

      it "returns an instance of Coverband::Utils::FileList for source_files and files" do
        assert subject.files.is_a?(Coverband::Utils::FileList)
        assert subject.source_files.is_a?(Coverband::Utils::FileList)
      end

      it "has files equal to source_files" do
        assert_equal subject.source_files, subject.files
      end

      it "has accurate covered percent" do
        # in our fixture, there are 13 covered line (result in 1) in all 15 relevant line (result in non-nil)
        assert_equal 86.66666666666667, subject.covered_percent
      end

      it "has accurate covered percentages" do
        assert_equal [80.0, 80.0, 100.0], subject.covered_percentages
      end

      %i[covered_percent
         covered_percentages
         covered_strength
         covered_lines
         missed_lines
         total_lines].each do |msg|
        it "responds to #{msg}" do
          assert(subject.respond_to?(msg))
        end
      end
    end
  end
end
