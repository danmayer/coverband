# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

####
# Thanks for all the help SimpleCov https://github.com/colszowka/simplecov-html
# initial version of test pulled into Coverband from Simplecov 12/19/2018
####
describe Coverband::Utils::Line do
  describe "a source line" do
    subject do
      Coverband::Utils::Line.new("# the ruby source", 5, 3)
    end

    it 'returns "# the ruby source" as src' do
      assert_equal "# the ruby source", subject.src
    end

    it "returns the same for source as for src" do
      assert_equal subject.src, subject.source
    end

    it "has line number 5" do
      assert_equal 5, subject.line_number
    end

    it "has equal line_number, line and number" do
      assert_equal subject.line, subject.line_number
      assert_equal subject.number, subject.line_number
    end

    describe "flagged as skipped!" do
      before do
        subject.skipped!
      end
      it "is not covered" do
        refute subject.covered?
      end

      it "is skipped" do
        assert subject.skipped?
      end

      it "is not missed" do
        refute subject.missed?
      end

      it "is not never" do
        refute subject.never?
      end

      it "status is skipped" do
        assert_equal "skipped", subject.status
      end
    end
  end

  describe "A source line with coverage" do
    subject do
      Coverband::Utils::Line.new("# the ruby source", 5, 3)
    end

    it "has coverage of 3" do
      assert_equal 3, subject.coverage
    end

    it "is covered" do
      assert subject.covered?
    end

    it "is not skipped" do
      refute subject.skipped?
    end

    it "is not missed" do
      refute subject.missed?
    end

    it "is not never" do
      refute subject.never?
    end

    it "status is covered" do
      assert_equal "covered", subject.status
    end
  end

  describe "A source line without coverage" do
    subject do
      Coverband::Utils::Line.new("# the ruby source", 5, 0)
    end

    it "has coverage of 0" do
      assert_equal 0, subject.coverage
    end

    it "is not covered" do
      refute subject.covered?
    end

    it "is not skipped" do
      refute subject.skipped?
    end

    it "is missed" do
      assert subject.missed?
    end

    it "is not never" do
      refute subject.never?
    end

    it "status is missed" do
      assert_equal "missed", subject.status
    end
  end

  describe "A source line with no code" do
    subject do
      Coverband::Utils::Line.new("# the ruby source", 5, nil)
    end

    it "has nil coverage" do
      assert_nil subject.coverage
    end

    it "is not covered" do
      refute subject.covered?
    end

    it "is not skipped" do
      refute subject.skipped?
    end

    it "is not missed" do
      refute subject.missed?
    end

    it "is never" do
      assert subject.never?
    end

    it "status is never" do
      assert_equal "never", subject.status
    end
  end

  it "raises ArgumentError when initialized with invalid src" do
    assert_raises ArgumentError do
      Coverband::Utils::Line.new(:symbol, 5, 3)
    end
  end

  it "raises ArgumentError when initialized with invalid line_number" do
    assert_raises ArgumentError do
      Coverband::Utils::Line.new("some source", "five", 3)
    end
  end

  it "raises ArgumentError when initialized with invalid coverage" do
    assert_raises ArgumentError do
      Coverband::Utils::Line.new("some source", 5, "three")
    end
  end
end
