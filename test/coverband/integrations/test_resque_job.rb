class TestResqueJob
  @queue = :resque_coverband

  def self.perform
    "resque job perform"
  end
end
