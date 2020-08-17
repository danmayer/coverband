# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require File.expand_path("../../../lib/coverband/adapters/web_service_store", File.dirname(__FILE__))

class WebServiceStoreTest < Minitest::Test
  COVERBAND_SERVICE_URL = "http://localhost:12345"
  FAKE_API_KEY = "12345"

  def setup
    WebMock.disable_net_connect!
    super
    @store = Coverband::Adapters::WebServiceStore.new(COVERBAND_SERVICE_URL)
    Coverband.configuration.store = @store
  end

  def test_coverage
    Coverband.configuration.api_key = FAKE_API_KEY
    stub_request(:post, "#{COVERBAND_SERVICE_URL}/api/collector").to_return(body: {status: "OK"}.to_json, status: 200)
    mock_file_hash
    @store.save_report(basic_coverage)
  end

  # TODO: sort out a retry test
  # def test_retries
  #   Coverband.configuration.api_key = FAKE_API_KEY
  #   stub_request(:post, "#{COVERBAND_SERVICE_URL}/api/collector").to_return(body: {status: "OK"}.to_json, status: 200)
  #   mock_file_hash
  #   @store.save_report(basic_coverage)
  # end

  def test_no_webservice_call_without_api_key
    Coverband.configuration.api_key = nil
    mock_file_hash
    @store.save_report(basic_coverage)
  end

  def test_clear
    assert_raises RuntimeError do
      @store.clear!
    end
  end

  def test_clear_file
    assert_raises RuntimeError do
      @store.clear_file!("app_path/dog.rb")
    end
  end

  def test_size
    mock_file_hash
    @store.type = :eager_loading
    @store.save_report("app_path/dog.rb" => [0, 1, 1])
    assert @store.size, 1
  end
end
