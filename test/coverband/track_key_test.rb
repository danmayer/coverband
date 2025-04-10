# frozen_string_literal: true

require File.expand_path("../test_helper", File.dirname(__FILE__))

class TrackKeyTest < Minitest::Test
  test "track_key accepts supported tracker types" do
    mock_view_tracker = mock
    mock_view_tracker.expects(:track_key).with("view/path/index.html.erb").returns(true)
    Coverband.configuration.expects(:view_tracker).returns(mock_view_tracker)
    
    assert Coverband.track_key(:view_tracker, "view/path/index.html.erb")
  end

  test "track_key raises ArgumentError for unsupported tracker type" do
    assert_raises ArgumentError do
      Coverband.track_key(:unsupported_tracker, "some_key")
    end
  end

  test "track_key returns false for nil key" do
    assert_equal false, Coverband.track_key(:view_tracker, nil)
  end

  test "track_key handles missing trackers" do
    Coverband.configuration.expects(:view_tracker).returns(nil)
    
    assert_equal false, Coverband.track_key(:view_tracker, "some_view")
  end

  test "track_key handles trackers without track_key method" do
    mock_invalid_tracker = mock
    mock_invalid_tracker.expects(:respond_to?).with(:track_key).returns(false)
    Coverband.configuration.expects(:view_tracker).returns(mock_invalid_tracker)
    
    assert_equal false, Coverband.track_key(:view_tracker, "some_view")
  end

  test "track_key with translations_tracker" do
    mock_translations_tracker = mock
    mock_translations_tracker.expects(:track_key).with("translation.key").returns(true)
    Coverband.configuration.expects(:translations_tracker).returns(mock_translations_tracker)
    
    assert Coverband.track_key(:translations_tracker, "translation.key")
  end

  test "track_key with routes_tracker" do
    mock_routes_tracker = mock
    mock_routes_tracker.expects(:track_key).with("index#show").returns(true)
    Coverband.configuration.expects(:routes_tracker).returns(mock_routes_tracker)
    
    assert Coverband.track_key(:routes_tracker, "index#show")
  end

  test "track_key logs error when tracking fails" do
    mock_logger = mock
    mock_logger.expects(:error).with(regexp_matches(/Failed to track key/))
    
    mock_tracker = mock
    mock_tracker.expects(:track_key).with("test_key").raises(StandardError.new("Test error"))
    
    Coverband.configuration.expects(:translations_tracker).returns(mock_tracker)
    Coverband.configuration.expects(:logger).returns(mock_logger)
    
    assert_equal false, Coverband.track_key(:translations_tracker, "test_key")
  end
end